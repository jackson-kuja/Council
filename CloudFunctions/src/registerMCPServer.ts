import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";

const elevenLabsApiKey = defineString("ELEVENLABS_API_KEY");

export const registerMCPServer = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { name, mcpUrl, authToken } = request.data;

  if (!name || !mcpUrl || !authToken) {
    throw new HttpsError("invalid-argument", "Missing required fields: name, mcpUrl, authToken");
  }

  logger.info("registerMCPServer called", { name, mcpUrl });

  try {
    const apiKey = elevenLabsApiKey.value();

    const body = {
      config: {
        name: name,
        url: mcpUrl,
        request_headers: {
          "Authorization": `Bearer ${authToken}`,
        },
        transport: "STREAMABLE_HTTP",
        approval_policy: "auto_approve_all",
      },
    };

    const response = await fetch("https://api.elevenlabs.io/v1/convai/mcp-servers", {
      method: "POST",
      headers: {
        "xi-api-key": apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    const responseText = await response.text();
    logger.info("ElevenLabs MCP register response", { status: response.status, body: responseText.substring(0, 500) });

    if (!response.ok) {
      throw new HttpsError("internal", `ElevenLabs MCP API error: ${response.status} - ${responseText}`);
    }

    const data = JSON.parse(responseText);
    return { mcpServerId: data.id || data.mcp_server_id };
  } catch (error: any) {
    logger.error("registerMCPServer error", { message: error.message });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to register MCP server: ${error.message}`);
  }
});
