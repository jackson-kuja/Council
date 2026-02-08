import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";

const elevenLabsApiKey = defineString("ELEVENLABS_API_KEY");

export const deleteAgent = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { agentId } = request.data;

  if (!agentId) {
    throw new HttpsError("invalid-argument", "Missing agentId");
  }

  try {
    const response = await fetch(
      `https://api.elevenlabs.io/v1/convai/agents/${agentId}`,
      {
        method: "DELETE",
        headers: {
          "xi-api-key": elevenLabsApiKey.value(),
        },
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      throw new HttpsError("internal", `Failed to delete agent: ${response.status} - ${errorText}`);
    }

    return { success: true };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to delete agent: ${error.message}`);
  }
});
