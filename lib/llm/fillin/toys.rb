# frozen_string_literal: true
require "securerandom"

module LLM
  module Fillin
    CREATE_TOY_V1 = {
      type: "object", additionalProperties: false,
      properties: {
        name: { type: "string", description: "Toy name" },
        category: { type: "string", enum: %w[plush puzzle doll car lego other] },
        price_minor: { type: "integer", minimum: 0, description: "Price in cents" },
        color: { type: "string", description: "Primary color" }
      },
      required: %w[name category price_minor]
    }

    def self.register_toy_tools!(registry)
      registry.register!(
        name: "create_toy", version: "v1",
        schema: CREATE_TOY_V1,
        description: "Create a toy with name, category, price (in cents), and optional color.",
        handler: ->(args, ctx) {
          key = Idempotency.generate(thread_id: ctx[:thread_id])
          {
            id: "TOY-#{SecureRandom.hex(3).upcase}",
            name: args["name"],
            category: args["category"],
            price_minor: args["price_minor"],
            color: args["color"] || "unspecified",
            created_by: ctx[:actor_id],
            tenant: ctx[:tenant_id],
            idempotency_key: key
          }
        }
      )
    end
  end
end
