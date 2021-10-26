# AICenter Entity Recovery Script for Automation Suite
Recovery script to be triggered before bringing up an AIC instance after any disaster or recovery.

### How to use
For help menu
```
./entity_recovery.sh -h
```
```
./entity_recovery.sh --help
```

To execute script
```
./entity_recovery.sh -c <s2s_client_id> -i 'https://staging.uipath.com/identity_/connect/token' -s 'AiFabricRecovery' -p <s2s_client_secret>
```

with long options
```
./entity_recovery.sh --clientId <s2s_client_id> --identityServerUrl 'https://staging.uipath.com/identity_/connect/token' --scope 'AiFabricRecovery' --clientSecret <s2s_client_secret>
```

