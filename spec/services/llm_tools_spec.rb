# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLMTools do
  let(:args) do
    {
      system_prompt: " sys\n",
      messages: [
        { role: 'user', content: "user 1\n" },
        { role: 'assistant', content: 'bot reply' },
        { role: 'user', content: 'user 2' }
      ]
    }
  end
  let(:expected_messages) do
    [
      { role: 'system', content: 'sys' },
      { role: 'user', content: 'user 1' },
      { role: 'assistant', content: 'bot reply' },
      { role: 'user', content: 'user 2' }
    ]
  end

  before do
    allow(GenericInferenceApi).to receive(:run_chat_completion).and_return 'cloud output'
    allow(LocalInferenceApi).to receive_messages(
      run_chat_completion: 'local output',
      config: ActiveSupport::OrderedOptions[split_replies: true]
    )
    allow(Rails.application.credentials).to receive(:openai)
      .and_return ActiveSupport::OrderedOptions[model: 'cloud-model']
  end

  describe '.chat_completion' do
    context 'when local LLM is available' do
      before { allow(LocalInferenceApi).to receive(:available_model).and_return 'koboldcpp/local-model' }

      it 'uses local LLM with its settings' do
        expect(described_class.chat_completion(**args))
          .to eq LLMTools::Completion.new(text: 'local output', split_replies: true)
        expect(LocalInferenceApi).to have_received(:run_chat_completion)
          .with(model: 'koboldcpp/local-model', messages: expected_messages, model_params: {})
        expect(GenericInferenceApi).not_to have_received(:run_chat_completion)
      end

      [Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError].each do |error_class|
        context "when local LLM request fails with #{error_class}" do
          before do
            allow(LocalInferenceApi).to receive(:run_chat_completion).and_raise error_class
            allow(LocalInferenceApi).to receive(:mark_unavailable!)
          end

          it 'falls back to cloud provider with its settings' do
            expect(described_class.chat_completion(**args))
              .to eq LLMTools::Completion.new(text: 'cloud output', split_replies: false)
            expect(LocalInferenceApi).to have_received(:mark_unavailable!).with(an_instance_of(error_class))
            expect(GenericInferenceApi).to have_received(:run_chat_completion)
              .with(messages: expected_messages, model_params: {})
          end
        end
      end

      context 'when local LLM request fails with a non-HTTP error' do
        before { allow(LocalInferenceApi).to receive(:run_chat_completion).and_raise ArgumentError }

        it 'raises instead of hiding the bug behind the fallback' do
          expect { described_class.chat_completion(**args) }.to raise_error ArgumentError
          expect(GenericInferenceApi).not_to have_received(:run_chat_completion)
        end
      end

      context 'when cloud provider also fails' do
        before do
          allow(LocalInferenceApi).to receive(:run_chat_completion).and_raise Faraday::ConnectionFailed
          allow(GenericInferenceApi).to receive(:run_chat_completion).and_raise Faraday::ServerError
        end

        it 'raises the cloud provider error' do
          expect { described_class.chat_completion(**args) }.to raise_error Faraday::ServerError
        end
      end
    end

    context 'when huggingface provider is configured' do
      before do
        allow(LocalInferenceApi).to receive(:available_model).and_return nil
        allow(Rails.application.credentials).to receive(:llm_api_provider).and_return 'huggingface'
        allow(HuggingfaceInferenceApi).to receive(:run_chat_completion).and_return 'hf output'
      end

      it 'uses huggingface API' do
        expect(described_class.chat_completion(**args).text).to eq 'hf output'
        expect(HuggingfaceInferenceApi).to have_received(:run_chat_completion)
          .with(messages: expected_messages, model_params: {})
      end
    end

    context 'when local LLM is unavailable' do
      before { allow(LocalInferenceApi).to receive(:available_model).and_return nil }

      it 'uses cloud provider' do
        expect(described_class.chat_completion(**args))
          .to eq LLMTools::Completion.new(text: 'cloud output', split_replies: false)
        expect(GenericInferenceApi).to have_received(:run_chat_completion)
          .with(messages: expected_messages, model_params: {})
        expect(LocalInferenceApi).not_to have_received(:run_chat_completion)
      end
    end
  end

  describe '.chat_completion with progress' do
    let(:progress) { instance_double(LLMProgress, llm_started: nil, llm_output: nil) }

    before do
      allow(LocalInferenceApi).to receive(:available_model).and_return 'koboldcpp/local-model'
      allow(LocalInferenceApi).to receive(:run_chat_completion) do |&block|
        %w[a b].each(&block)
        'local output'
      end
      allow(GenericInferenceApi).to receive(:run_chat_completion) do |&block|
        block.call('c')
        'cloud output'
      end
    end

    it 'reports the provider and full prompt, then each piece of output' do
      described_class.chat_completion(**args, progress:)

      expect(progress).to have_received(:llm_started)
        .with(having_attributes(model: 'koboldcpp/local-model', self_hosted: true), expected_messages).ordered
      expect(progress).to have_received(:llm_output).with('a').ordered
      expect(progress).to have_received(:llm_output).with('b').ordered
    end

    it 'reports the cloud provider again on fallback' do
      allow(LocalInferenceApi).to receive(:run_chat_completion).and_raise Faraday::ConnectionFailed
      allow(LocalInferenceApi).to receive(:mark_unavailable!)

      described_class.chat_completion(**args, progress:)

      expect(progress).to have_received(:llm_started)
        .with(having_attributes(model: 'cloud-model', self_hosted: false), expected_messages)
      expect(progress).to have_received(:llm_output).with('c')
    end

    it 'works without progress' do
      expect(described_class.chat_completion(**args).text).to eq 'local output'
    end
  end

  describe '.chat_completion with a callable system prompt' do
    let(:providers) { [] }
    let(:system_prompt) do
      lambda do |provider|
        providers << provider
        "prompt for #{provider.model}"
      end
    end

    before { allow(LocalInferenceApi).to receive(:available_model).and_return 'koboldcpp/local-model' }

    it 'builds system prompt for the local provider' do
      described_class.chat_completion(system_prompt:, messages: args[:messages])

      expect(providers).to eq [LLMTools::Provider.new(model: 'koboldcpp/local-model', self_hosted: true,
                                                      split_replies: true)]
      expect(LocalInferenceApi).to have_received(:run_chat_completion).with(
        hash_including(messages: [{ role: 'system', content: 'prompt for koboldcpp/local-model' },
                                  *expected_messages[1..]])
      )
    end

    it 'rebuilds system prompt for the cloud provider on fallback' do
      allow(LocalInferenceApi).to receive(:run_chat_completion).and_raise Faraday::ConnectionFailed
      allow(LocalInferenceApi).to receive(:mark_unavailable!)

      described_class.chat_completion(system_prompt:, messages: args[:messages])

      expect(providers.last).to eq LLMTools::Provider.new(model: 'cloud-model', self_hosted: false,
                                                          split_replies: false)
      expect(GenericInferenceApi).to have_received(:run_chat_completion).with(
        hash_including(messages: [{ role: 'system', content: 'prompt for cloud-model' }, *expected_messages[1..]])
      )
    end
  end

  describe '.reply_prompt' do
    let(:bot_config) { Rails.application.credentials.telegram.bot }
    let(:local) { LLMTools::Provider.new(model: 'hf.co/someone/Some-Model-GGUF:Q6_K', self_hosted: true, split_replies: true) }
    let(:cloud) { LLMTools::Provider.new(model: 'llama-3.3-70b', self_hosted: false, split_replies: false) }

    it 'does not reveal which model or machine it is running on' do
      [local, cloud].each do |provider|
        prompt = described_class.reply_prompt(provider)

        expect(prompt).not_to include provider.model.split('/').last
        expect(prompt).not_to match(/own PC|cloud API|running as/i)
      end
    end

    it 'is identical for different models with the same split_replies setting' do
      other_local = local.with(model: 'another-model', self_hosted: false)

      expect(described_class.reply_prompt(other_local)).to eq described_class.reply_prompt(local)
    end

    it "includes ReplyJob#perform's source code" do
      expect(described_class.reply_prompt(local)).to include "```ruby\ndef perform(db_chat, serialized_message)\n"
    end

    it 'does not @ the owner outside of the instruction about @-ing them' do
      mentions = described_class.reply_prompt(local).lines.grep(/@#{bot_config.owner_username}/o)

      expect(mentions.size).to eq 1
      expect(mentions.first).to include "don't @ them"
    end
  end

  describe '.prompt_completion' do
    before { allow(LocalInferenceApi).to receive(:available_model).and_return nil }

    it 'sends system & user prompt, returns only the output text' do
      output = described_class.prompt_completion(system_prompt: 'sys', user_prompt: 'user',
                                                 model_params: { temperature: 0.5 })

      expect(output).to eq 'cloud output'
      expect(GenericInferenceApi).to have_received(:run_chat_completion).with(
        messages: [{ role: 'system', content: 'sys' }, { role: 'user', content: 'user' }],
        model_params: { temperature: 0.5 }
      )
    end
  end
end
