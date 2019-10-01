        {
            spec    => 'retry=i',
            field   => 'retry',
            used_by => {jobs => 1},
            section => 'Job Options',
            usage   => ['--retry=1'],
            summary => ['Run any jobs that failed a second time. NOTE: --retry=1 means failing tests will be attempted twice!'],
            default => 0,
        },
        {
            spec    => 'retry-job-count=i',
            field   => 'retry_job_count',
            used_by => {jobs => 1},
            section => 'Job Options',
            usage   => ['--retry-job-count=1'],
            summary => ['When re-running failed tests, use a different number of parallel jobs. You might do this if your tests are not reliably parallel safe'],
            default => 0,
        },
    );
}


