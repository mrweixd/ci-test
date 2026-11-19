# ULCL Internet probes fail with mismatched routing and NAT

## Symptoms

N6GW/MEC connectivity checks pass, but UE Internet probes to 1.1.1.1 fail.

## Cause

A PSA-UPF connects to both `privnet` and `n6-net`. Its UE MASQUERADE rule targets the N6 interface selected by `natIfCIDR: 10.100.50.0/24`, but Docker may select the internal-network gateway as the default route. Internet traffic then leaves through an interface without the matching UE NAT rule.

## Diagnosis

Inspect each PSA-UPF after startup:

```bash
docker exec psa-upf-0 ip -br addr
docker exec psa-upf-0 ip route get 1.1.1.1
docker exec psa-upf-0 iptables -t nat -S POSTROUTING
```

The Internet route must use the intended N6 gateway and interface, and the UE MASQUERADE rule must target that same interface. Identify the interface from its subnet rather than assuming it is always eth0 or eth1.

## Compose configuration

Both ULCL Compose files set `gw_priority: 1` on each PSA-UPF's `n6-net` attachment. Docker Compose 2.33.1 or later selects this network for the default gateway. Recreate the stack after changing its network configuration. See [Docker's gateway priority documentation](https://docs.docker.com/reference/compose-file/services/#gw_priority).

The N6GW test target at 10.100.50.10 is on the PSA's directly connected subnet. If it also fails, inspect N9 forwarding and the PSA's N6 NAT counters before attributing the failure to the default route.
