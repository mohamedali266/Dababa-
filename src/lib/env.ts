import { z } from "zod";

const envSchema = z.object({
  ADMIN_LOGIN_EMAIL: z.string().email().optional().or(z.literal("")),
  ADMIN_LOGIN_PASSWORD: z.string().min(12).optional().or(z.literal("")),
  ADMIN_LOGIN_USERNAME: z.string().min(2).optional().or(z.literal("")),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().optional().or(z.literal("")),
  NEXT_PUBLIC_SUPABASE_URL: z.string().url().optional().or(z.literal("")),
  QR_SIGNING_SECRET: z.string().min(32).optional().or(z.literal("")),
  SUPABASE_SERVICE_ROLE_KEY: z.string().optional().or(z.literal("")),
});

export type Env = z.infer<typeof envSchema>;

export function getEnv(): Env {
  const parsed = envSchema.safeParse(process.env);

  if (!parsed.success) {
    throw new Error(`Invalid environment: ${parsed.error.issues.map((issue) => issue.path.join(".")).join(", ")}`);
  }

  return parsed.data;
}
