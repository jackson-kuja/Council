import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";
import {
  audioTagsFromStyle,
  clampSpeechSpeed,
  turnEagernessFromPace,
} from "./agentStyle";

const elevenLabsApiKey = defineString("ELEVENLABS_API_KEY");

export const createAgent = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to create a coach");
  }

  const {
    name,
    systemPrompt,
    firstMessage,
    voiceId,
    llmModel,
    speechSpeed,
    responsePace,
    quickReplies,
    expressiveStyle,
  } = request.data;
  logger.info("createAgent called", {
    name,
    voiceId,
    llmModel,
    speechSpeed,
    responsePace,
    quickReplies,
    expressiveStyle,
    hasPrompt: !!systemPrompt,
  });

  if (!name || !systemPrompt || !voiceId) {
    throw new HttpsError("invalid-argument", "Missing required fields: name, systemPrompt, voiceId");
  }

  try {
    const apiKey = elevenLabsApiKey.value();
    logger.info("API key loaded", { keyLength: apiKey?.length ?? 0 });

    const safeSpeechSpeed = clampSpeechSpeed(speechSpeed, 1.0);
    const turnEagerness = turnEagernessFromPace(responsePace, "normal");
    const suggestedAudioTags = audioTagsFromStyle(expressiveStyle);

    const body = {
      name: name,
      conversation_config: {
        tts: {
          voice_id: voiceId,
          model_id: "eleven_v3_conversational",
          speed: safeSpeechSpeed,
          suggested_audio_tags: suggestedAudioTags,
        },
        turn: {
          turn_eagerness: turnEagerness,
          speculative_turn: quickReplies === true,
        },
        agent: {
          first_message: firstMessage || "Hello! How can I help you today?",
          language: "en",
          prompt: {
            prompt: systemPrompt,
            llm: llmModel || "gpt-4o",
            temperature: 0.7,
          },
        },
      },
      platform_settings: {
        overrides: {
          conversation_config_override: {
            agent: {
              prompt: { prompt: true },
              first_message: true,
            },
          },
        },
      },
    };

    logger.info("Sending request to ElevenLabs");

    const response = await fetch("https://api.elevenlabs.io/v1/convai/agents/create", {
      method: "POST",
      headers: {
        "xi-api-key": apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    const responseText = await response.text();
    logger.info("ElevenLabs response", { status: response.status, body: responseText.substring(0, 500) });

    if (!response.ok) {
      throw new HttpsError("internal", `ElevenLabs API error: ${response.status} - ${responseText}`);
    }

    const data = JSON.parse(responseText);
    return { agentId: data.agent_id };
  } catch (error: any) {
    logger.error("createAgent error", { message: error.message, stack: error.stack });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to create agent: ${error.message}`);
  }
});
