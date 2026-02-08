import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";

const elevenLabsApiKey = defineString("ELEVENLABS_API_KEY");

export const deleteMCPServer = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { mcpServerId } = request.data;

  if (!mcpServerId) {
    throw new HttpsError("invalid-argument", "Missing required field: mcpServerId");
  }

  logger.info("deleteMCPServer called", { mcpServerId });

  try {
    const apiKey = elevenLabsApiKey.value();

    const response = await fetch(`https://api.elevenlabs.io/v1/convai/mcp-servers/${mcpServerId}`, {
      method: "DELETE",
      headers: {
        "xi-api-key": apiKey,
      },
    });

    if (!response.ok) {
      const responseText = await response.text();
      logger.error("ElevenLabs MCP delete error", { status: response.status, body: responseText.substring(0, 500) });
      throw new HttpsError("internal", `ElevenLabs MCP API error: ${response.status} - ${responseText}`);
    }

    return { success: true };
  } catch (error: any) {
    logger.error("deleteMCPServer error", { message: error.message });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to delete MCP server: ${error.message}`);
  }
});
