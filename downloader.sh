# You can run this script with:
# curl -sSL https://raw.githubusercontent.com/fedimint/fedimint-docker/master/downloader.sh | bash

# 1. Check and install docker
DOCKER_COMPOSE="docker compose"
check_and_install_docker() {
  echo "Checking docker and other required dependencies..."
  # Check if Docker is installed
  if ! [ -x "$(command -v docker)" ]; then
    # Check if we are running as root
    if [ "$EUID" -ne 0 ]; then
      echo 'Error: Docker is not installed and we cannot install it for you without root privileges.' >&2
      exit 1
    fi

    # Install Docker using Docker's convenience script
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
  fi

  # Check if Docker Compose plugin is available
  if ! docker compose version >/dev/null 2>&1; then
    echo 'Error: Docker Compose plugin is not available. Please install it manually.' >&2
    exit 1
  fi

  echo "Docker and Docker Compose are ready."
}

# 2. Selectors for Install Type:
FEDIMINT_SERVICE=""
# 2a. Guardian or Gateway
select_guardian_or_gateway() {
  echo
  echo "Install a Fedimint Guardian or a Lightning Gateway?"
  echo
  echo "1. Fedimint Guardian"
  echo "2. Lightning Gateway"
  echo
  read -p "Enter your choice (1 or 2): " install_type
  while true; do
    case $install_type in
    1)
      FEDIMINT_SERVICE="guardian"
      break
      ;;
    2)
      FEDIMINT_SERVICE="gateway"
      break
      ;;
    *) echo "Invalid choice. Please enter 1 or 2." ;;
    esac
  done
}

# 2b. Mainnet or Mutinynet
select_mainnet_or_mutinynet() {
  echo
  echo "Run on Mainnet or Mutinynet?"
  echo
  echo "1. Mainnet"
  echo "2. Mutinynet"
  echo
  read -p "Enter your choice (1 or 2): " mainnet_or_mutinynet
  while true; do
    case $mainnet_or_mutinynet in
    1)
      FEDIMINT_SERVICE=$FEDIMINT_SERVICE+"_mainnet"
      break
      ;;
    2)
      FEDIMINT_SERVICE=$FEDIMINT_SERVICE+"_mutinynet"
      break
      ;;
    *) echo "Invalid choice. Please enter 1 or 2." ;;
    esac
  done
}

# 3c-guardian. Bitcoind or Esplora
select_bitcoind_or_esplora() {
  echo
  echo "Run with Bitcoind or Esplora?"
  echo
  echo "1. Bitcoind"
  echo "2. Esplora"
  echo
  read -p "Enter your choice (1 or 2): " bitcoind_or_esplora
  while true; do
    case $bitcoind_or_esplora in
    1)
      FEDIMINT_SERVICE=$FEDIMINT_SERVICE+"_bitcoind"
      break
      ;;
    2)
      FEDIMINT_SERVICE=$FEDIMINT_SERVICE+"_esplora"
      break
      ;;
    *) echo "Invalid choice. Please enter 1 or 2." ;;
    esac
  done
}

# 3c-gateway. New or Existing LND
select_local_or_remote_lnd() {
  echo
  echo "Connect to a remote LND node or start a new LND node on this machine?"
  echo
  echo "1. Remote"
  echo "2. Local"
  echo
  read -p "Enter your choice (1 or 2): " local_or_remote_lnd
  while true; do
    case $local_or_remote_lnd in
    1)
      FEDIMINT_SERVICE=$FEDIMINT_SERVICE+"_remote"
      break
      ;;
    2)
      FEDIMINT_SERVICE=$FEDIMINT_SERVICE+"_local"
      break
      ;;
    *) echo "Invalid choice. Please enter 1 or 2." ;;
    esac
  done
}

# 3d-guardian. New or Existing Bitcoind
select_local_or_remote_bitcoind() {
  echo
  echo "Run with Local (start a new Bitcoind node) or Remote (connect to an existing Bitcoind node)?"
  echo
  echo "1. Local"
  echo "2. Remote"
  echo
  read -p "Enter your choice (1 or 2): " local_or_remote_bitcoind
  while true; do
    case $local_or_remote_bitcoind in
    1)
      FEDIMINT_SERVICE=$FEDIMINT_SERVICE+"_local"
      break
      ;;
    2)
      FEDIMINT_SERVICE=$FEDIMINT_SERVICE+"_remote"
      break
      ;;
    *) echo "Invalid choice. Please enter 1 or 2." ;;
    esac
  done
}

# 4. Build the service dir and download the docker-compose and .env files
build_service_dir() {
  echo "Creating directory $INSTALL_DIR..."
  mkdir -p "$INSTALL_DIR"

  BASE_URL="https://raw.githubusercontent.com/fedimint/fedimint-docker/master/configurations/$FEDIMINT_SERVICE"

  echo "Downloading docker-compose.yaml..."
  curl -sSL "$BASE_URL/docker-compose.yaml" -o "$INSTALL_DIR/docker-compose.yaml"

  echo "Downloading .env file..."
  curl -sSL "$BASE_URL/.env" -o "$INSTALL_DIR/.env"

  echo "Files downloaded successfully."
}

# INSTALLER
installer() {
  check_and_install_docker
  select_guardian_or_gateway
  select_mainnet_or_mutinynet
  if [[ "$FEDIMINT_SERVICE" == "guardian"* ]]; then
    select_bitcoind_or_esplora
    if [[ "$FEDIMINT_SERVICE" == *"_bitcoind" ]]; then
      select_local_or_remote_bitcoind
    fi
  else
    select_local_or_remote_lnd
  fi

  build_service_dir
}

# 5. Set env vars
set_env_vars() {
  echo "Setting environment variables..."

  # Read the .env file line by line
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    if [[ -z "$line" ]]; then
      continue
    fi

    # If it's a comment, store it
    if [[ $line == \#* ]]; then
      comment="$line"
    # If it's a variable
    elif [[ $line == *=* ]]; then
      # Split the line into variable name and value
      var_name="${line%%=*}"
      var_value="${line#*=}"

      # Remove quotes from the value if present
      var_value="${var_value%\"}"
      var_value="${var_value#\"}"

      # Display the comment, variable name, and current value
      echo "$comment"
      echo "Current value of $var_name: $var_value"

      # Ask user if they want to change the value
      read -p "Do you want to change this value? (y/N): " change_value

      if [[ $change_value =~ ^[Yy]$ ]]; then
        # If yes, prompt for new value
        read -p "Enter new value for $var_name: " new_value
        # Update the value in the .env file
        sed -i "s|^$var_name=.*|$var_name=\"$new_value\"|" "$INSTALL_DIR/.env"
        echo "Updated $var_name to: $new_value"
      else
        echo "Keeping current value for $var_name"
      fi

      echo # Add a blank line for readability
    fi
  done <"$INSTALL_DIR/.env"

  # Source the updated .env file
  source "$INSTALL_DIR/.env"
  echo "Environment variables set."
}

# 6. Verify DNS
verify_dns() {
  EXTERNAL_IP=$(curl -4 -sSL ifconfig.me)
  echo "Setting up TLS certificates and DNS records:"
  echo "Your ip is $EXTERNAL_IP. You __must__ open the port 443 on your firewall to setup the TLS certificates."
  echo "If you are unable to open this port, then the TLS setup and everything else will catastrophically or silently fail."
  echo "So in this case you can not use this script and you must setup the TLS certificates manually or use a script without TLS"
  read -p "Press enter to acknowledge this " -r -n 1 </dev/tty
  echo
  echo "Create a DNS record pointing to this machine's ip: $EXTERNAL_IP"
  echo "Once you've set it up, enter the host_name here: (e.g. fedimint.com)"
  read -p "Enter the host_name: " host_name
  echo "Verifying DNS..."
  echo
  echo "DNS propagation may take a while and and caching may cause issues,"
  echo "you can verify the DNS mapping in another terminal with:"
  echo "${host_name[*]} -> $EXTERNAL_IP"
  echo "Using dig: dig +short $host_name"
  echo "Using nslookup: nslookup $host_name"
  echo
  read -p "Press enter after you have verified them" -r -n 1 </dev/tty
  echo
  while true; do
    error=""
    echo "Checking DNS records..."
    resolved_host=$(resolve_host $hose_name)
    if [[ -z $resolved_host ]]; then
      echo "Error: $hose_name does not resolve to anything!"
      error=true
    elif [[ $resolved_host != "$EXTERNAL_IP" ]]; then
      echo "Error: $hose_name does not resolve to $EXTERNAL_IP, it resolves to $resolved_host"
      error=true
    fi

    if [[ -z $error ]]; then
      echo "All DNS records look good"
      break
    else
      echo "Some DNS records are not correct"
      read -p "Check again? [Y/n] " -n 1 -r -a check_again </dev/tty
      if [[ ${check_again[*]} =~ ^[Yy]?$ ]]; then
        continue
      else
        echo
        echo "If you are sure the DNS records are correct, you can continue without checking"
        echo "But if there is some issue with them, the Let's Encrypt certificates will not be able to be created"
        echo "And you may receive a throttle error from Let's Encrypt that may take hours to go away"
        echo "Therefore we recommend you double check everything"
        echo "If you suspect it's just a caching issue, then wait a few minutes and try again. Do not continue."
        echo
        read -p "Continue without checking? [y/N] " -n 1 -r -a continue_without_checking </dev/tty
        echo
        if [[ ${continue_without_checking[*]} =~ ^[Yy]$ ]]; then
          echo "You have been warned, continuing..."
          break
        fi
      fi
    fi
  done
}

# 7. Run the service
run_service() {
  echo "Running the service..."
  cd "$INSTALL_DIR" && docker compose up -d
}

# MAIN SCRIPT

INSTALL_DIR="fedimint-service"
if [ -d "$INSTALL_DIR" ]; then
  echo "ERROR: Directory $INSTALL_DIR exists."
  echo "You can run the service with: cd $INSTALL_DIR && docker compose up -d"
  echo "If you want to re-run the installer to create a different service,"
  echo "please remove the directory first or run the installer from a fresh directory / machine."
  exit 1
fi

installer
set_env_vars
verify_dns
run_service
