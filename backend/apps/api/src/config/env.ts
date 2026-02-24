import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().default("redis://localhost:6379"),
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z
    .enum(["development", "production", "test"])
    .default("development"),
  API_KEY: z.string().optional(),
  MIGROS_REGION: z.string().default("national"),
  MIGROS_LANGUAGE: z.enum(["de", "fr", "it", "en"]).default("de"),
  LLM_PROVIDER: z.enum(["openai", "anthropic", "perplexity", "gemini"]).default("openai"),
  OPENAI_API_KEY: z.string().optional(),
  ANTHROPIC_API_KEY: z.string().optional(),
  PERPLEXITY_API_KEY: z.string().optional(),
  GEMINI_API_KEY: z.string().optional(),
  LLM_MODEL: z.string().optional(),
  ENABLE_BACKGROUND_JOBS: z
    .union([z.literal("1"), z.literal("0"), z.boolean()])
    .optional()
    .transform((v) => (v === true || v === "1")),
  GOOGLE_CLIENT_ID: z.string().optional(),
  JWT_SECRET: z.string().min(32),
  APPLE_BUNDLE_ID: z.string().default("com.pantrypilot.app"),
});

export type Env = z.infer<typeof envSchema>;

let _env: Env | undefined;

export function getEnv(): Env {
  if (!_env) {
    const result = envSchema.safeParse(process.env);
    if (!result.success) {
      console.error("Invalid environment variables:", result.error.flatten());
      process.exit(1);
    }
    _env = result.data;
  }
  return _env;
}
