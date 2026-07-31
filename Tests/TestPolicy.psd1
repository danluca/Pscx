@{
    # Test-only dependency. It is saved beneath .tools and is never packaged.
    PesterVersion = '6.0.0'

    # Conservative initial gates based on the Phase 2.2 smoke suites. Raise
    # these independently as tests migrate; never combine the percentages.
    ManagedCoverageMinimumPercent = 1
    PowerShellCoverageMinimumPercent = 5
}
