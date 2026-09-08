#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for x-dockhand-agent.
# Idempotent: safe to run multiple times on the same host.
#
# What it does, in order:
#   1. Ensures .env exists (copies from .env.example if missing)
#   2. Ensures every required variable in .env has a real value
#      (prompts interactively for anything missing/placeholder)
#   3. Ensures the external Docker volume exists
#   4. Starts the stack with `docker compose up -d`

ENV_FILE=".env"
ENV_EXAMPLE="env.example"

# List every variable the compose file actually needs.
REQUIRED_VARS=(
  CT_HOSTNAME
  DH_AGENT_NAME
  DH_MAIN_HOSTNAME
  DH_TOKEN
)

# Variables that should be read silently (not echoed to the terminal).
SECRET_VARS=(
  DH_TOKEN
)

# --- Step 1: ensure .env exists -------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$ENV_EXAMPLE" ]]; then
    echo "No .env found — creating one from $ENV_EXAMPLE"
    cp "$ENV_EXAMPLE" "$ENV_FILE"
  else
    echo "No .env or .env.example found — creating an empty .env"
    touch "$ENV_FILE"
  fi
fi

# --- Helpers ----------------------------------------------------------------

# Get the current value of a key from .env (empty string if not set).
get_env_value() {
  local key="$1"
  # Matches KEY=value lines, ignores comments, trims the key= prefix.
  grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d '=' -f2- || true
}

# Set (or update) a key in .env.
set_env_value() {
  local key="$1"
  local value="$2"
  if grep -qE "^${key}=" "$ENV_FILE" 2>/dev/null; then
    # Key exists — replace its line.
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    rm -f "${ENV_FILE}.bak"
  else
    # Key missing entirely — append it.
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

# A value counts as "not really set" if it's empty or still looks like a
# placeholder (e.g. "changeme", "your_token_here", or wrapped in <angle brackets>).
is_placeholder() {
  local value="$1"
  if [[ -z "$value" ]]; then
    return 0
  fi
  if [[ "$value" =~ ^\<.*\>$ ]] || [[ "$value" =~ ^(changeme|your_.*_here|todo|xxx)$ ]]; then
    return 0
  fi
  return 1
}

is_secret_var() {
  local key="$1"
  for s in "${SECRET_VARS[@]}"; do
    [[ "$s" == "$key" ]] && return 0
  done
  return 1
}

# --- Step 2: fill in any missing/placeholder variables ----------------------
missing_any=false
for var in "${REQUIRED_VARS[@]}"; do
  current_value="$(get_env_value "$var")"
  if is_placeholder "$current_value"; then
    missing_any=true
    if is_secret_var "$var"; then
      read -r -s -p "Enter value for $var (input hidden): " new_value
      echo
    else
      read -r -p "Enter value for $var: " new_value
    fi
    if [[ -z "$new_value" ]]; then
      echo "Error: $var cannot be empty. Aborting." >&2
      exit 1
    fi
    set_env_value "$var" "$new_value"
  fi
done

if [[ "$missing_any" == true ]]; then
  echo ".env is now complete."
else
  echo ".env already has all required variables set."
fi

# --- Step 3: ensure the external volume exists -------------------------------
# The volume name depends on DH_AGENT_NAME, so read it back from .env
# after step 2 (it's guaranteed to be set by now).
AGENT_NAME="$(get_env_value DH_AGENT_NAME)"
VOLUME_NAME="x-dockhand-stacks_${AGENT_NAME}"

if docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
  echo "Volume '$VOLUME_NAME' already exists."
else
  echo "Volume '$VOLUME_NAME' not found — creating it."
  docker volume create "$VOLUME_NAME" >/dev/null
fi

# --- Step 4: start the stack --------------------------------------------------
echo "Starting the stack..."
docker compose up -d

echo "Done. Check the Dockhand dashboard to confirm the agent is online."