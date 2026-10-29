# MixSIARPFN: MixSIAR models fitted by prior-data fitted networks

Load data with [`load_mix_data()`](load_mix_data.md),
[`load_source_data()`](load_source_data.md) and
[`load_discr_data()`](load_discr_data.md) as in MixSIAR, fit with
[`run_pfn()`](run_pfn.md) (in place of `write_JAGS_model()` and
`run_model()`), and summarise with [`output_pfn()`](output_pfn.md) (in
place of `output_JAGS()`). The posteriors come from networks trained on
simulations from MixSIAR's model, one per error structure, downloaded on
first use (see [`pfn_networks()`](pfn_networks.md)).

## Details

The example data are from MixSIAR (Stock et al. 2018, PeerJ 6:e5096):
the killer whale, geese and wolves vignettes.

## See also

Useful links:

- <https://github.com/andrewcparnell/MixSIARPFN>

- Report bugs at <https://github.com/andrewcparnell/MixSIARPFN/issues>

## Author

**Maintainer**: Andrew Parnell <Andrew.parnell1@ucd.ie>

Authors:

- Andrew Parnell <Andrew.parnell1@ucd.ie>
