import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";

const elevenLabsApiKey = defineString("ELEVENLABS_API_KEY");

export const updateAgent = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { agentId, llmModel, systemPrompt, firstMessage, voiceId, ttsModelId } =
    request.data;
  logger.info("updateAgent called", { agentId, llmModel, voiceId, ttsModelId });

  if (!agentId) {
    throw new HttpsError("invalid-argument", "Missing agentId");
  }

  try {
    const apiKey = elevenLabsApiKey.value();

    // Build patch body with only provided fields
    const patch: any = { conversation_config: {} };

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

    if (voiceId || ttsModelId) {
      patch.conversation_config.tts = {};
      if (voiceId) patch.conversation_config.tts.voice_id = voiceId;
      if (ttsModelId) patch.conversation_config.tts.model_id = ttsModelId;
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
