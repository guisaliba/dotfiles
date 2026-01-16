# Agentic memory system

- information retrieval is hard to solve, but easy to verify.
- instead of having a sophisticated system to curate memory offline, at realtime, storing memories with citations is a cheaper and more efficient approach.
- citations are references to specific code locations that support each fact.
- agents simply verifies citations in realtime, validating that the memory is accurate and up-to-date.
- that boils down to simple read operations.
- for example, while iterating over a codebase and given a task, an agent might find out that an information must stay in sync across multiple parts of the codebase:
1. at the client-side: `export const API_VERSION = "v2.1.4";`
2. at the server-side: `const APIVersion = "v2.1.4"`
3. at a documentation: `Version: v2.1.4`
the agent can then use a tool to create a memory for this:

```json
{
  subject: "API version synchronization", 
  fact: "API version must match between client SDK, server routes, and documentation.",
  citations: ["src/client/sdk/constants.ts:12", "server/routes/api.go:8", "docs/api-reference.md:37"], 
  reason: "If the API version is not kept properly synchronized, the integration can fail or exhibit subtle bugs. Remembering these locations will help ensure they are kept syncronized in future updates."
}
```
next time an agent updates the API version in any of these locations, it'll see this memory and update all of them tree at the same time.

- to not lose that on every new session, a Memory DB is needed. the agent writes that memory to the db, and simply retrieves from it on next iterations.
- the agent enriches the prompt it got from the user with the retrieved content from the Memory DB before iterating on the task.
- but before applying a memory it checks at realtime whether that memory is still accurate by checking the cited code locations.
- if the code contradicts the memory, the agent is encouraged to update the memory with the new evidence.

