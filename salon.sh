#! /bin/bash

run_sql() {
  psql --username=freecodecamp --dbname=salon -X -qAt "$@"
}

print_services() {
  run_sql -F '|' -c "SELECT service_id, name FROM services ORDER BY service_id" |
    while IFS='|' read -r service_id service_name; do
      printf '%s) %s\n' "$service_id" "$service_name"
    done
}

lookup_service() {
  run_sql -v service_id="$1" -f - <<'SQL'
SELECT name FROM services WHERE service_id::text = :'service_id';
SQL
}

lookup_customer() {
  run_sql -v phone="$1" -f - <<'SQL'
SELECT customer_id FROM customers WHERE phone = :'phone';
SQL
}

printf '\n~~~~~ MY SALON ~~~~~\n\n'
printf 'Welcome to My Salon, how can I help you?\n\n'
print_services

read SERVICE_ID_SELECTED
SERVICE_NAME=$(lookup_service "$SERVICE_ID_SELECTED")

while [[ -z "$SERVICE_NAME" ]]; do
  printf '\nI could not find that service. What would you like today?\n'
  print_services
  read SERVICE_ID_SELECTED
  SERVICE_NAME=$(lookup_service "$SERVICE_ID_SELECTED")
done

printf "\nWhat's your phone number?\n"
read CUSTOMER_PHONE

CUSTOMER_ID=$(lookup_customer "$CUSTOMER_PHONE")

if [[ -z "$CUSTOMER_ID" ]]; then
  printf "\nI don't have a record for that phone number, what's your name?\n"
  read CUSTOMER_NAME
  CUSTOMER_ID=$(run_sql -v phone="$CUSTOMER_PHONE" -v name="$CUSTOMER_NAME" -f - <<'SQL'
INSERT INTO customers (phone, name) VALUES (:'phone', :'name') RETURNING customer_id;
SQL
)
else
  CUSTOMER_NAME=$(run_sql -v customer_id="$CUSTOMER_ID" -f - <<'SQL'
SELECT name FROM customers WHERE customer_id = :'customer_id';
SQL
)
fi

printf "\nWhat time would you like your %s, %s?\n" "$SERVICE_NAME" "$CUSTOMER_NAME"
read SERVICE_TIME

run_sql -v customer_id="$CUSTOMER_ID" -v service_id="$SERVICE_ID_SELECTED" -v service_time="$SERVICE_TIME" -f - <<'SQL'
INSERT INTO appointments (customer_id, service_id, time) VALUES (:'customer_id', :'service_id', :'service_time');
SQL

printf '\nI have put you down for a %s at %s, %s.\n' "$SERVICE_NAME" "$SERVICE_TIME" "$CUSTOMER_NAME"