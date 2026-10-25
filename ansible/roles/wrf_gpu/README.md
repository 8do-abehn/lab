# wrf_gpu

Builds a CUDA WRF VM (#609, #631): an Ubuntu 24.04 VM with a passed-through
NVIDIA GPU that runs [wrf_gpu](https://github.com/wrf-gpu/wrf_gpu) (a JAX
rewrite of WRF v4), plus the CPU WRF and WPS builds that prepare its input and
give it something to be compared against. It reproduces what was built by hand
on wrf01, so a new VM (or a rebuilt wrf01) is one playbook run.

Not wired to any host yet. The `wrf_servers` group and its inventory entries
come with #632; until then the play in `site.yml` matches no hosts.

## What it installs

| Path | What |
|------|------|
| driver | `nvidia-headless-580-open` + `nvidia-utils-580` (CUDA 13), `qemu-guest-agent`. The VM reboots once to load the module |
| `/opt/wrf/wrf_gpu` | wrf_gpu at a pinned tag, venv in `.venv` with `jax[cuda13]==0.10.*` and `filelock` |
| `/opt/wrf/WRF` | WRF v4.7.1, serial (configure option 32, basic nesting). Gives `real.exe`, and its `run/` holds the tables wrf_gpu reads |
| `/opt/wrf/WRF_dmpar` | The same source, dmpar (option 34), for CPU comparison runs |
| `/opt/wrf/WPS` | WPS v4.6.0, built with `--build-grib2-libs` against the serial WRF |
| `/opt/wrf/netcdf` | A unified NetCDF prefix pointing at the Ubuntu packages, see below |
| `/opt/wrf/WPS_GEOG_LOW_RES` | WPS mandatory static data, low-res set |
| `/opt/wrf/wgrib2` | wgrib2 built from source (not packaged on noble), linked as `/usr/local/bin/wgrib2` |
| `/opt/wrf/herbie/.venv` | Herbie, for downloading GFS/HRRR (#633) |

Every build is skipped when its output already exists. They take 10-40 minutes
each, so a rerun is quick and check mode never compiles anything.

## Changing a version

The WRF, WPS and wgrib2 clones are gated on their directories, not managed by
the git module, so bumping `wrf_version`, `wps_version` or `wgrib2_version`
does nothing to an existing VM. Move the old tree aside and rerun. wrf_gpu is
different: its version is checked against the installed `gpuwrf` package and
reinstalled when the pin changes.

## Why a unified NetCDF prefix

Ubuntu puts the NetCDF-C and NetCDF-Fortran headers in `/usr/include` and the
libraries in `/usr/lib/x86_64-linux-gnu`. WRF's configure only adds
`-lnetcdff` when it finds the library under `$NETCDF/lib`. Pointed at `/usr`,
the link fails with `undefined reference to nf_*`. `/opt/wrf/netcdf` has
`include` linked to `/usr/include` and `lib/` holding links to each
`libnetcdf*`. Builds run with `NETCDF=/opt/wrf/netcdf NETCDF_classic=1`.

## Running

wrf_gpu needs the WRF tree for its runtime tables:

```
export GPUWRF_WRF_ROOT=/opt/wrf/WRF
/opt/wrf/wrf_gpu/.venv/bin/python -c "import jax; print(jax.devices())"
```

The Noah-MP tables (`MPTABLE.TBL` and friends) live in the
`phys/noahmp` submodule, which is why WRF is cloned with
`--recurse-submodules`. The role links any that are missing into `run/`.

### dmpar hangs (unresolved)

`mpirun -np 8 wrf.exe` from `WRF_dmpar` never finishes reading `wrfinput`:
rank 0 spins in `outbuf_2_patch_r` (`wrf_global_to_patch`) while the other
ranks wait in `MPI_Bcast`. `ulimit -s unlimited` does not fix it, and with
`--mca btl_vader_single_copy_mechanism none` it segfaults in the same routine
instead. The serial build works. Candidates for later: smpar (option 33) or
`-O1` for `frame/`. See #631.

## Not covered

- The high-res WPS_GEOG set. wrf01 has it, but it made no difference to the
  results there, and it is large. Download it by hand if a case needs it.
- Tailscale, the inventory entry and the PCI mapping for the GPU (#632, #609).
