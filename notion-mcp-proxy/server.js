import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { Client } from "@notionhq/client";
import express from "express";
import { z } from "zod";

const app = express();
// Only parse JSON for non-MCP routes; the MCP transport reads the raw body stream itself
app.use((req, res, next) => {
  if (req.path === "/mcp") return next();
  express.json()(req, res, next);
});

// Health check
app.get("/", (_req, res) => res.send("ok"));

// Session tracking
const sessions = new Map();

app.post("/mcp", async (req, res) => {
  console.log(`POST /mcp — session: ${req.headers["mcp-session-id"] || "none"}, content-type: ${req.headers["content-type"]}, accept: ${req.headers["accept"]}`);

  try {
    // Extract Notion token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      console.log("Missing Authorization Bearer token");
      res.status(401).json({ error: "Missing Authorization Bearer token" });
      return;
    }
    const notionToken = authHeader.slice(7);

    // Check for existing session
    const sessionId = req.headers["mcp-session-id"];

    if (sessionId && sessions.has(sessionId)) {
      console.log(`Reusing existing session: ${sessionId}`);
      const transport = sessions.get(sessionId);
      await transport.handleRequest(req, res);
      return;
    }

    // New session — create MCP server with this user's Notion token
    console.log("Creating new MCP session...");
    const server = createMcpServer(notionToken);
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: () => crypto.randomUUID() });

    transport.onclose = () => {
      const sid = transport.sessionId;
      console.log(`Session closed: ${sid}`);
      if (sid) sessions.delete(sid);
    };

    await server.connect(transport);

    await transport.handleRequest(req, res);

    // Session ID is assigned after handleRequest processes the initialize message
    if (transport.sessionId) {
      sessions.set(transport.sessionId, transport);
      console.log(`New session created: ${transport.sessionId}`);
    }
    console.log(`POST handled, response status: ${res.statusCode}`);
  } catch (err) {
    console.error("POST /mcp error:", err);
    if (!res.headersSent) {
      res.status(500).json({ error: err.message });
    }
  }
});

app.get("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"];
  console.log(`GET /mcp — session: ${sessionId || "none"}`);

  try {
    if (sessionId && sessions.has(sessionId)) {
      const transport = sessions.get(sessionId);
      await transport.handleRequest(req, res);
    } else {
      res.status(400).json({ error: "No session" });
    }
  } catch (err) {
    console.error("GET /mcp error:", err);
    if (!res.headersSent) {
      res.status(500).json({ error: err.message });
    }
  }
});

app.delete("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"];
  console.log(`DELETE /mcp — session: ${sessionId || "none"}`);

  try {
    if (sessionId && sessions.has(sessionId)) {
      const transport = sessions.get(sessionId);
      await transport.handleRequest(req, res);
      sessions.delete(sessionId);
    } else {
      res.status(404).json({ error: "Session not found" });
    }
  } catch (err) {
    console.error("DELETE /mcp error:", err);
    if (!res.headersSent) {
      res.status(500).json({ error: err.message });
    }
  }
});

function createMcpServer(notionToken) {
  const notion = new Client({ auth: notionToken });

  const server = new McpServer({
    name: "notion-proxy",
    version: "1.0.0",
  });

  // Search pages and databases
  server.tool("notion_search", "Search for pages and databases in the user's Notion workspace", {
    query: z.string().optional().describe("Search query text"),
  }, async ({ query }) => {
    const response = await notion.search({
      query: query || "",
      page_size: 10,
    });
    const results = response.results.map((r) => ({
      id: r.id,
      type: r.object,
      title: extractTitle(r),
      url: r.url,
    }));
    return { content: [{ type: "text", text: JSON.stringify(results, null, 2) }] };
  });

  // Get page content
  server.tool("notion_get_page", "Get a Notion page's properties and content blocks", {
    page_id: z.string().describe("The Notion page ID"),
  }, async ({ page_id }) => {
    const [page, blocks] = await Promise.all([
      notion.pages.retrieve({ page_id }),
      notion.blocks.children.list({ block_id: page_id, page_size: 100 }),
    ]);
    const content = {
      title: extractTitle(page),
      properties: simplifyProperties(page.properties),
      content: blocks.results.map(simplifyBlock),
    };
    return { content: [{ type: "text", text: JSON.stringify(content, null, 2) }] };
  });

  // Create a page
  server.tool("notion_create_page", "Create a new page in a Notion database or as a child of another page", {
    parent_id: z.string().describe("Parent page or database ID"),
    parent_type: z.string().describe("'database_id' or 'page_id'"),
    title: z.string().describe("Page title"),
    content: z.string().optional().describe("Plain text content for the page body"),
  }, async ({ parent_id, parent_type, title, content }) => {
    const parent = parent_type === "database_id"
      ? { database_id: parent_id }
      : { page_id: parent_id };

    const properties = parent_type === "database_id"
      ? { title: { title: [{ text: { content: title } }] } }
      : {};

    const children = [];
    if (parent_type !== "database_id") {
      children.push({
        object: "block",
        type: "heading_1",
        heading_1: { rich_text: [{ text: { content: title } }] },
      });
    }
    if (content) {
      children.push({
        object: "block",
        type: "paragraph",
        paragraph: { rich_text: [{ text: { content } }] },
      });
    }

    const page = await notion.pages.create({ parent, properties, children });
    return { content: [{ type: "text", text: JSON.stringify({ id: page.id, url: page.url }, null, 2) }] };
  });

  // Update page properties
  server.tool("notion_update_page", "Update a Notion page's properties", {
    page_id: z.string().describe("The Notion page ID"),
    properties: z.string().describe("JSON string of properties to update"),
  }, async ({ page_id, properties }) => {
    const parsed = JSON.parse(properties);
    const page = await notion.pages.update({ page_id, properties: parsed });
    return { content: [{ type: "text", text: JSON.stringify({ id: page.id, url: page.url }, null, 2) }] };
  });

  // Add content block to a page
  server.tool("notion_append_block", "Append content blocks to a Notion page", {
    page_id: z.string().describe("The page ID to append to"),
    text: z.string().describe("Text content to append as a paragraph"),
  }, async ({ page_id, text }) => {
    const response = await notion.blocks.children.append({
      block_id: page_id,
      children: [{
        object: "block",
        type: "paragraph",
        paragraph: { rich_text: [{ text: { content: text } }] },
      }],
    });
    return { content: [{ type: "text", text: `Appended ${response.results.length} block(s)` }] };
  });

  // List databases
  server.tool("notion_list_databases", "List all databases accessible in the user's Notion workspace", {}, async () => {
    const response = await notion.search({
      filter: { property: "object", value: "database" },
      page_size: 20,
    });
    const databases = response.results.map((db) => ({
      id: db.id,
      title: extractTitle(db),
      url: db.url,
    }));
    return { content: [{ type: "text", text: JSON.stringify(databases, null, 2) }] };
  });

  // Query a database
  server.tool("notion_query_database", "Query a Notion database for entries", {
    database_id: z.string().describe("The database ID to query"),
    query: z.string().optional().describe("Optional search filter text"),
  }, async ({ database_id, query }) => {
    const params = { database_id, page_size: 20 };
    const response = await notion.databases.query(params);
    const entries = response.results.map((page) => ({
      id: page.id,
      title: extractTitle(page),
      properties: simplifyProperties(page.properties),
      url: page.url,
    }));
    return { content: [{ type: "text", text: JSON.stringify(entries, null, 2) }] };
  });

  return server;
}

// Helper: extract title from a page or database
function extractTitle(obj) {
  if (obj.properties) {
    for (const [, prop] of Object.entries(obj.properties)) {
      if (prop.type === "title" && prop.title?.length > 0) {
        return prop.title.map((t) => t.plain_text).join("");
      }
    }
  }
  if (obj.title) {
    if (Array.isArray(obj.title)) {
      return obj.title.map((t) => t.plain_text).join("");
    }
  }
  return "Untitled";
}

// Helper: simplify properties for readability
function simplifyProperties(properties) {
  if (!properties) return {};
  const result = {};
  for (const [key, prop] of Object.entries(properties)) {
    switch (prop.type) {
      case "title":
        result[key] = prop.title?.map((t) => t.plain_text).join("") || "";
        break;
      case "rich_text":
        result[key] = prop.rich_text?.map((t) => t.plain_text).join("") || "";
        break;
      case "number":
        result[key] = prop.number;
        break;
      case "select":
        result[key] = prop.select?.name || null;
        break;
      case "multi_select":
        result[key] = prop.multi_select?.map((s) => s.name) || [];
        break;
      case "date":
        result[key] = prop.date?.start || null;
        break;
      case "checkbox":
        result[key] = prop.checkbox;
        break;
      case "url":
        result[key] = prop.url;
        break;
      case "email":
        result[key] = prop.email;
        break;
      case "phone_number":
        result[key] = prop.phone_number;
        break;
      case "status":
        result[key] = prop.status?.name || null;
        break;
      default:
        result[key] = `[${prop.type}]`;
    }
  }
  return result;
}

// Helper: simplify block for readability
function simplifyBlock(block) {
  const type = block.type;
  const data = block[type];
  let text = "";
  if (data?.rich_text) {
    text = data.rich_text.map((t) => t.plain_text).join("");
  }
  return { type, text, id: block.id };
}

const PORT = parseInt(process.env.PORT || "8080");
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Notion MCP proxy running on port ${PORT}`);
});
