import tailwindcss from "@tailwindcss/vite";
import StimulusHMR from "vite-plugin-stimulus-hmr";
import FullReload from "vite-plugin-full-reload";
import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";

export default defineConfig({
  plugins: [FullReload(["config/routes.rb", "app/views/**/*"]), StimulusHMR(), tailwindcss(), RubyPlugin()],
  server: { allowedHosts: ["vite"] },
});
