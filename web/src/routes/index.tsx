import { createFileRoute } from "@tanstack/react-router";
import { Atelier } from "@/components/ink/Atelier";

export const Route = createFileRoute("/")({ component: Home });

function Home() {
  return <Atelier />;
}
