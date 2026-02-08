import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";

const elevenLabsApiKey = defineString("ELEVENLABS_API_KEY");

export const updateAgentMCP = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { agentId, mcpServerIds } = request.data;

  if (!agentId) {
    throw new HttpsError("invalid-argument", "Missing required field: agentId");
  }

  logger.info("updateAgentMCP called", { agentId, mcpServerIds });

  try {
    const apiKey = elevenLabsApiKey.value();

    const body = {
      conversation_config: {
        agent: {
          prompt: {
            mcp_server_ids: mcpServerIds || [],
          },
        },
      },
    };

    const response = await fetch(`https://api.elevenlabs.io/v1/convai/agents/${agentId}`, {
      method: "PATCH",
      headers: {
        "xi-api-key": apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    const responseText = await response.text();
    logger.info("ElevenLabs agent MCP update response", { status: response.status, body: responseText.substring(0, 500) });

    if (!response.ok) {
      throw new HttpsError("internal", `ElevenLabs API error: ${response.status} - ${responseText}`);
    }

    return { success: true };
  } catch (error: any) {
    logger.error("updateAgentMCP error", { message: error.message });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to update agent MCP: ${error.message}`);
  }
});
