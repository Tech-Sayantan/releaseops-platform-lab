package com.releaseops.releases;

import jakarta.validation.Valid;
import java.net.URI;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/releases")
public class ReleaseController {

    private final List<StoredRelease> releases = new ArrayList<>();

    @PostMapping
    ResponseEntity<StoredRelease> create(@Valid @RequestBody ReleaseRecord request) {
        StoredRelease stored = new StoredRelease(UUID.randomUUID().toString(), request);
        releases.add(stored);
        return ResponseEntity.created(URI.create("/releases/" + stored.id())).body(stored);
    }

    @GetMapping
    List<StoredRelease> list() {
        return releases;
    }

    @GetMapping("/{id}")
    ResponseEntity<StoredRelease> get(@PathVariable String id) {
        return releases.stream()
                .filter(release -> release.id().equals(id))
                .findFirst()
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }
}
