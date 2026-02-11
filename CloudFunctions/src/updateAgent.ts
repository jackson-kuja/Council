import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";
import {
  audioTagsFromStyle,
  clampSpeechSpeed,
  turnEagernessFromPace,
} from "./agentStyle";

const elevenLabsApiKey = defineString("ELEVENLABS_API_KEY");

export const updateAgent = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const {
    agentId,
    llmModel,
    systemPrompt,
    firstMessage,
    voiceId,
    speechSpeed,
    responsePace,
    quickReplies,
    expressiveStyle,
  } = request.data;
  logger.info("updateAgent called", {
    agentId,
    llmModel,
    voiceId,
    speechSpeed,
    responsePace,
    quickReplies,
    expressiveStyle,
  });

  if (!agentId) {
    throw new HttpsError("invalid-argument", "Missing agentId");
  }

  try {
    const apiKey = elevenLabsApiKey.value();

    const patch: any = {
      conversation_config: {
        tts: {
          model_id: "eleven_v3_conversational",
        },
      },
    };

    if (llmModel || systemPrompt) {
      patch.conversation_config.agent = { prompt: {} };
      if (llmModel) patch.conversation_config.agent.prompt.llm = llmModel;
      if (systemPrompt)
        patch.conversation_config.agent.prompt.prompt = systemPrompt;
    }

    if (firstMessage) {
      if (!patch.conversation_config.agent)
        patch.conversation_config.agent = {};
      patch.conversation_config.agent.first_message = firstMessage;
    }

    if (voiceId || speechSpeed !== undefined || expressiveStyle !== undefined) {
      if (voiceId) patch.conversation_config.tts.voice_id = voiceId;
      if (speechSpeed !== undefined) {
        patch.conversation_config.tts.speed = clampSpeechSpeed(speechSpeed, 1.0);
      }
      if (expressiveStyle !== undefined) {
        patch.conversation_config.tts.suggested_audio_tags = audioTagsFromStyle(expressiveStyle);
      }
    }

    if (responsePace !== undefined || quickReplies !== undefined) {
      patch.conversation_config.turn = {};
      if (responsePace !== undefined) {
        patch.conversation_config.turn.turn_eagerness = turnEagernessFromPace(
          responsePace,
          "normal"
        );
      }
      if (quickReplies !== undefined) {
        patch.conversation_config.turn.speculative_turn = quickReplies === true;
      }
    }

    logger.info("Patching agent", {
      agentId,
      patchKeys: JSON.stringify(Object.keys(patch.conversation_config)),
    });

    const response = await fetch(
      `https://api.elevenlabs.io/v1/convai/agents/${agentId}`,
      {
        method: "PATCH",
        headers: {
          "xi-api-key": apiKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(patch),
      }
    );

    const responseText = await response.text();
    logger.info("ElevenLabs response", {
      status: response.status,
      body: responseText.substring(0, 500),
    });

    if (!response.ok) {
      throw new HttpsError(
        "internal",
        `ElevenLabs API error: ${response.status} - ${responseText}`
      );
    }

    return { success: true };
  } catch (error: any) {
    logger.error("updateAgent error", {
      message: error.message,
      stack: error.stack,
    });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      `Failed to update agent: ${error.message}`
    );
  }
});
