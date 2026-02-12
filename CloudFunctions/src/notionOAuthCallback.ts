import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

/**
 * HTTP endpoint that Notion redirects to after OAuth authorization.
 * Receives the auth code and redirects to the iOS app via custom URL scheme.
 *
 * Notion requires HTTPS redirect URIs, so we bounce through this function:
 *   Notion → https://[project].cloudfunctions.net/notionOAuthCallback?code=xxx
 *        → council://notion-callback?code=xxx → iOS app
 */
export const notionOAuthCallback = onRequest(async (req, res) => {
  const code = req.query.code as string | undefined;
  const error = req.query.error as string | undefined;

  logger.info("notionOAuthCallback", { hasCode: !!code, error });

  if (error) {
    res.status(400).send(`OAuth error: ${error}`);
    return;
  }

  if (!code) {
    res.status(400).send("Missing authorization code");
    return;
  }

  // Redirect to the iOS app with the authorization code
  const appRedirect = `council://notion-callback?code=${encodeURIComponent(code)}`;
  res.redirect(302, appRedirect);
});
