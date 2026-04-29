#!/usr/bin/env bats
# Unit tests for pick_ipv6() in bin/azure-ddns.
#
# Strategy: dot-source the script (its source-guard prevents the main
# flow from running) and shadow `ip` with a per-test stub that emits
# canned JSON. jq runs for real against each fixture.

setup() {
    # shellcheck disable=SC1090
    source "${BATS_TEST_DIRNAME}/../bin/azure-ddns"
    set +eu
}

@test "slaac-stable: picks the kernel-managed stable address over the temporary" {
    ip() { printf '%s' '[{"ifname":"eth0","addr_info":[
        {"family":"inet6","local":"2001:db8::stable","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":14400},
        {"family":"inet6","local":"2001:db8::dead","scope":"global","dynamic":true,"temporary":true,"preferred_life_time":86400}
    ]}]'; }
    AZURE_DDNS_IPV6_SELECT=slaac-stable run pick_ipv6
    [ "$status" -eq 0 ]
    [ "$output" = "2001:db8::stable" ]
}

@test "slaac-stable: is the default when AZURE_DDNS_IPV6_SELECT is unset" {
    ip() { printf '%s' '[{"ifname":"eth0","addr_info":[
        {"family":"inet6","local":"2001:db8::1","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":14400}
    ]}]'; }
    unset AZURE_DDNS_IPV6_SELECT
    run pick_ipv6
    [ "$status" -eq 0 ]
    [ "$output" = "2001:db8::1" ]
}

@test "slaac-temporary: picks the RFC 4941 temporary address" {
    ip() { printf '%s' '[{"ifname":"eth0","addr_info":[
        {"family":"inet6","local":"2001:db8::stable","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":14400},
        {"family":"inet6","local":"2001:db8::dead:beef","scope":"global","dynamic":true,"temporary":true,"preferred_life_time":86400}
    ]}]'; }
    AZURE_DDNS_IPV6_SELECT=slaac-temporary run pick_ipv6
    [ "$status" -eq 0 ]
    [ "$output" = "2001:db8::dead:beef" ]
}

@test "static: picks admin-configured (non-dynamic, non-temporary) address" {
    ip() { printf '%s' '[{"ifname":"eth0","addr_info":[
        {"family":"inet6","local":"2001:db8::static","scope":"global","preferred_life_time":4294967295},
        {"family":"inet6","local":"2001:db8::auto","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":14400}
    ]}]'; }
    AZURE_DDNS_IPV6_SELECT=static run pick_ipv6
    [ "$status" -eq 0 ]
    [ "$output" = "2001:db8::static" ]
}

@test "literal: returns the address when present on host" {
    ip() { printf '%s' '[{"ifname":"eth0","addr_info":[
        {"family":"inet6","local":"2001:db8::1","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":14400}
    ]}]'; }
    AZURE_DDNS_IPV6_SELECT=2001:db8::1 run pick_ipv6
    [ "$status" -eq 0 ]
    [ "$output" = "2001:db8::1" ]
}

@test "literal: warns and returns empty when address not present" {
    ip() { printf '%s' '[{"ifname":"eth0","addr_info":[
        {"family":"inet6","local":"2001:db8::1","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":14400}
    ]}]'; }
    AZURE_DDNS_IPV6_SELECT=2001:db8::dead run pick_ipv6
    [ "$status" -eq 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "filters out tentative addresses" {
    ip() { printf '%s' '[{"ifname":"eth0","addr_info":[
        {"family":"inet6","local":"2001:db8::tentative","scope":"global","dynamic":true,"mngtmpaddr":true,"tentative":true,"preferred_life_time":14400},
        {"family":"inet6","local":"2001:db8::ready","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":7200}
    ]}]'; }
    AZURE_DDNS_IPV6_SELECT=slaac-stable run pick_ipv6
    [ "$status" -eq 0 ]
    [ "$output" = "2001:db8::ready" ]
}

@test "filters out deprecated addresses" {
    ip() { printf '%s' '[{"ifname":"eth0","addr_info":[
        {"family":"inet6","local":"2001:db8::old","scope":"global","dynamic":true,"mngtmpaddr":true,"deprecated":true,"preferred_life_time":0},
        {"family":"inet6","local":"2001:db8::new","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":7200}
    ]}]'; }
    AZURE_DDNS_IPV6_SELECT=slaac-stable run pick_ipv6
    [ "$status" -eq 0 ]
    [ "$output" = "2001:db8::new" ]
}

@test "filters out ULA addresses (fc00::/7)" {
    ip() { printf '%s' '[{"ifname":"eth0","addr_info":[
        {"family":"inet6","local":"fd12:3456:789a::1","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":86400}
    ]}]'; }
    AZURE_DDNS_IPV6_SELECT=slaac-stable run pick_ipv6
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "tie-break: longest preferred lifetime wins among stable candidates" {
    ip() { printf '%s' '[{"ifname":"eth0","addr_info":[
        {"family":"inet6","local":"2001:db8::short","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":3600},
        {"family":"inet6","local":"2001:db8::long","scope":"global","dynamic":true,"mngtmpaddr":true,"preferred_life_time":86400}
    ]}]'; }
    AZURE_DDNS_IPV6_SELECT=slaac-stable run pick_ipv6
    [ "$status" -eq 0 ]
    [ "$output" = "2001:db8::long" ]
}

@test "invalid mode dies with error" {
    ip() { printf '%s' '[]'; }
    AZURE_DDNS_IPV6_SELECT=garbage run pick_ipv6
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid"* ]]
}

@test "empty ip output returns nothing" {
    ip() { printf ''; }
    AZURE_DDNS_IPV6_SELECT=slaac-stable run pick_ipv6
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no global addresses on host returns empty" {
    ip() { printf '%s' '[]'; }
    AZURE_DDNS_IPV6_SELECT=slaac-stable run pick_ipv6
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
