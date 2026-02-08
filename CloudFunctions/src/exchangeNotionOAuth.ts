import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";

const notionClientId = defineString("NOTION_CLIENT_ID");
const notionClientSecret = defineString("NOTION_CLIENT_SECRET");

export const exchangeNotionOAuth = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { code, redirectUri } = request.data;

  if (!code || !redirectUri) {
    throw new HttpsError("invalid-argument", "Missing required fields: code, redirectUri");
  }

  logger.info("exchangeNotionOAuth called", { hasCode: !!code, redirectUri });

  try {
    const clientId = notionClientId.value();
    const clientSecret = notionClientSecret.value();
    const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");

    const response = await fetch("https://api.notion.com/v1/oauth/token", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${credentials}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirectUri,
      }),
    });

    const responseText = await response.text();
    logger.info("Notion OAuth response", { status: response.status });

    if (!response.ok) {
      throw new HttpsError("internal", `Notion OAuth error: ${response.status} - ${responseText}`);
    }

    const data = JSON.parse(responseText);
    return {
      accessToken: data.access_token,
      workspaceId: data.workspace_id || "",
      workspaceName: data.workspace_name || "",
    };
  } catch (error: any) {
    logger.error("exchangeNotionOAuth error", { message: error.message });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to exchange OAuth code: ${error.message}`);
  }
});
