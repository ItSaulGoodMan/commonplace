import { handle } from './api';
import { type Deps, liveDeps } from './deps';
import { ApiError, errorResponse, logError } from './http';

/** The Worker's fetch handler, with its outside world passed in. */
export function makeFetch(deps: Deps) {
  return async (request: Request, env: Env, ctx: ExecutionContext): Promise<Response> => {
    try {
      return await handle(request, env, ctx, deps);
    } catch (e) {
      if (e instanceof ApiError) return errorResponse(e);
      logError('unhandled', {
        error: String(e),
        stack: e instanceof Error ? e.stack : undefined,
      });
      return errorResponse(new ApiError('server', 'Something went wrong. Try again.'));
    }
  };
}

export default {
  fetch: makeFetch(liveDeps),
} satisfies ExportedHandler<Env>;
