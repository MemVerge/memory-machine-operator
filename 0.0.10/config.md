# List of Configurations for MemoryMachine
Configurations for MemoryMachine can be specified in the spec field of the MemoryMachine YAML file. Below are details about current available configurations.

**Note:** If a field is not specified in the YAML, and it has a default value, the default value will be used. Otherwise the field will be omitted.

## mmVersion

- Version of Memory Machine
- Type: string
- Default value: “master“

## pmemNsPerNode

- Number of Pmem devices used by the Memory Machine
- Type: int
- Default value: 1

**Note:** Currently the operator makes the following assumption: starting with index 0, that the `i` th PMEM device is mounted to `/mnt/pmem[i]`. For example, if there are 2 PMEM devices, they should be mounted to `/mnt/pmem0` and /`mnt/pmem1` on the local machine/VM. Otherwise, the operator will fail to create the MemoryMachine.

## licenseFromSecret

- Name of secret for MemoryMachine License
- Type: string
- Default value: "memory-machine-license"

## localSharedPath

- Local directory used for sharing socket and library files
- Type: string
- Default value: "/tmp/memverge"

## podPrefixList

- List of Pod Prefixes for injection
- Type: string slice (string[])

## daemonConfig

- Configuration for MemoryMachine Daemon (mvmallocd)
- Configurable parameters:
    - dpmeSocketName `string`
        - Default value: "/tmp/memverge/dpme_daemon.0"
    - pmem `string`
    - noDaemon `bool`
    - trace `bool`
	- eventLog `bool`
	- persistOnClose `bool`
	- logPath `string`
	- licensePath `string`
	- devUUID `string`
	- pmemEmulation `bool`
        
## mvmallocConfig

- Configuration for MemoryMachine shared library (mvmalloc.so)
- Cache Parameters:
	- dramCacheMB `uint64`
    	- Default value: 100
	- hugePageDram `bool`
    	- Default value: true
	- dramCacheNumaInterleave `bool`
	- dramTierNumaInterleave `bool`
	- dramCacheGB `uint64`
	- dramTierGB `uint64`
	- dramTierMB `uint64`
	- dramColdIntervals `uint64`
	- lruPollMsec `uint64`
	- maxCachePerPoll `uint64`
	- maxPromotePerPoll `uint64`
	- hugePagePath `string`
	- preallocateDram `bool`
	- rearmCycles `uint64`
	- faultSettleMs `uint64`
	- maxActivations `uint64`
	- dramIncrementSize `uint64`
- Other configurations
	- dpmeSocketName `string`
    	- Default value: "/tmp/memverge/dpme_daemon.0"
	- mmapCapture `bool`
    	- Default value: true
	- mallocCapture `bool`
    	- Default value: true
	- logNamePrefix `string`
    	- Default value: "/var/log/memverge/malloc_log"
	- logTrace `bool`
    	- Default value: false
	- commPort `uint64`
    	- Default value: 5678
	- useMulticast `bool`
    	- Default value: true
	- mallocMemoryMB `uint64`
	- outOfPmemFail `bool`
	- mmapForkWait `uint64`
	- mmapDelayStart `uint64`
	- mmapFlagAllow `string`
	- mmapFlagDisallow `string`
	- mmapDisallowedSize `uint64`
	- mmapAllowedSize `uint64`
	- mmapAllowFragment `bool`
	- logTruncate `bool`
	- logName `string`
	- checkConsistency `bool`
	- safeModeDefault `bool`
	- maxFaultPipes `uint64`
	- userfault `bool`
	- enableSnapshot `bool`
	- mallocHooks `bool`
	- disableDeepBind `bool`
	- disableCloneInstance `bool`
	- stopThreadInFork `bool`
	- useForkSnapshot `bool`
	- supportAddrHint `bool`
	- mallocUnitNum `uint64`
	- enableTraceLog `bool`
	- reservedMinFd `uint64`
	- accessDetector `string`
	- internalBatchReplacement `bool`
	- multicastAddr `string`

## mvservicedConfig

- Configuration for Mvsvcd (mvsvcd)
- Configurable parameters:
  - SocketPath `string`
    - Default value: "/tmp/libmvm_sock"
  - Daemonize `bool`
  - LogTrace `bool`