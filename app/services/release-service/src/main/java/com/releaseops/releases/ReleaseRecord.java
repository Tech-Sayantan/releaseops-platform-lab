package com.releaseops.releases;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record ReleaseRecord(
        @NotBlank String service,
        @NotBlank String environment,
        @Pattern(regexp = "^sha256:[0-9a-f]{64}$") String imageDigest,
        String status) {

    public ReleaseRecord {
        if (status == null || status.isBlank()) {
            status = "PENDING_APPROVAL";
        }
    }
}
