import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";

const elevenLabsApiKey = defineString("ELEVENLABS_API_KEY");

export const updateAgentMultiVoice = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { agentId, supportedVoices } = request.data;
  logger.info("updateAgentMultiVoice called", {
    agentId,
    voiceCount: supportedVoices?.length ?? 0,
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
          supported_voices: (supportedVoices || []).map((v: any) => ({
            voice_id: v.voiceId || v.voice_id,
            label: v.label,
            description: v.description || "",
          })),
        },
      },
    };

    logger.info("Patching agent multi-voice", {
      agentId,
      voiceCount: patch.conversation_config.tts.supported_voices.length,
      labels: patch.conversation_config.tts.supported_voices.map(
        (v: any) => v.label
      ),
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
    logger.error("updateAgentMultiVoice error", {
      message: error.message,
      stack: error.stack,
    });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      `Failed to update multi-voice: ${error.message}`
    );
  }
});
