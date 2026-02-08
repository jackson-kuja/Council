import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";

const elevenLabsApiKey = defineString("ELEVENLABS_API_KEY");

export const listVoices = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  try {
    const apiKey = elevenLabsApiKey.value();
    logger.info("listVoices called", { keyLength: apiKey?.length ?? 0 });

    const response = await fetch(
      "https://api.elevenlabs.io/v2/voices?page_size=50",
      {
        headers: {
          "xi-api-key": apiKey,
        },
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("listVoices API error", { status: response.status, body: errorText.substring(0, 500) });
      throw new HttpsError("internal", `Failed to fetch voices: ${response.status}`);
    }

    const data = await response.json();

    const voices = (data.voices || []).map((voice: any) => ({
      voice_id: voice.voice_id,
      name: voice.name,
      category: voice.category || "premade",
      preview_url: voice.preview_url,
      labels: voice.labels || {},
    }));

    logger.info("listVoices success", { count: voices.length });
    return { voices };
  } catch (error: any) {
    logger.error("listVoices error", { message: error.message });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to list voices: ${error.message}`);
  }
});
