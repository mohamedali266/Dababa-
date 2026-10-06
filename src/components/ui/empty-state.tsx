import { Dumbbell } from "lucide-react";
import { Badge } from "./badge";

export function EmptyState({ title, body }: { title: string; body: string }) {
  return (
    <section className="rounded-[2rem] border border-dashed border-[var(--border)] bg-surface p-8">
      <Badge className="mb-5 bg-accent text-on-accent">
        <Dumbbell className="me-2 size-4" />
        Dababa
      </Badge>
      <h2 className="text-2xl font-extrabold">{title}</h2>
      <p className="mt-3 max-w-xl text-sm leading-7 text-text-muted">{body}</p>
    </section>
  );
}
