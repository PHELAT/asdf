import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Watch, setupGlobalHandlers } from "@catdoes/watch-web";
import { WatchErrorBoundary } from "@catdoes/watch-web/react";
import { TooltipProvider } from "@/components/ui/tooltip";
import { Toaster } from "@/components/ui/sonner";
import { useState } from "react";

const watchClient = Watch.init({
  apiKey: import.meta.env.VITE_CATDOES_WATCH_KEY || "",
  debug: import.meta.env.DEV,
});

if (watchClient) {
  setupGlobalHandlers(watchClient);
}

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <QueryClientProvider client={queryClient}>
      <WatchErrorBoundary showDefaultFallback>
        <TooltipProvider>{children}</TooltipProvider>
        <Toaster />
      </WatchErrorBoundary>
    </QueryClientProvider>
  );
}
