/** Everything that touches the outside world, so tests can swap it. */
export interface Deps {
  now(): number;
  fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>;
  sleep(ms: number): Promise<void>;
}

export const liveDeps: Deps = {
  now: () => Date.now(),
  // Wrapped: calling the global fetch through another object throws
  // "Illegal invocation" in Workers.
  fetch: (input, init) => fetch(input, init),
  sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
};
