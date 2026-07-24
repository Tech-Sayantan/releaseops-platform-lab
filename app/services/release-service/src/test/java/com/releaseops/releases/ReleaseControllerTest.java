package com.releaseops.releases;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class ReleaseControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void createsReleaseWithImmutableDigest() throws Exception {
        mockMvc.perform(post("/releases")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "service": "release-service",
                                  "environment": "dev",
                                  "imageDigest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.release.status").value("PENDING_APPROVAL"))
                .andExpect(jsonPath("$.release.imageDigest").value(
                        "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"));
    }

    @Test
    void rejectsMutableOrMalformedDigest() throws Exception {
        mockMvc.perform(post("/releases")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "service": "release-service",
                                  "environment": "dev",
                                  "imageDigest": "latest"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void exposesReleaseList() throws Exception {
        mockMvc.perform(get("/releases"))
                .andExpect(status().isOk());
    }
}
