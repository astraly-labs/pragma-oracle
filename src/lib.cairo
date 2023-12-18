mod admin {
    mod admin;
}
mod entry {
    mod entry;
    mod structs;
}
mod operations {
    mod sorting {
        mod merge_sort;
    }
    mod time_series {
        mod convert;
        mod structs;
        mod scaler;
        mod metrics;
    }
}
mod oracle {
    mod oracle;
    mod mock_oracle;
}
mod publisher_registry {
    mod publisher_registry;
}
mod compute_engines {
    mod yield_curve {
        mod yield_curve;
    }
    mod summary_stats {
        mod summary_stats;
    }
}
mod upgradeable {
    mod upgradeable;
}
mod randomness {
    mod example_randomness;
    mod randomness;
}
#[cfg(test)]
mod tests {
    // mod test_oracle;
    // mod test_publisher_registry;
    // mod test_summary_stats;
    // mod test_yield_curve;
    mod test_randomness;
}

