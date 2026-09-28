import Foundation

// EXPERIMENTAL -- Intelligence V1.4B architecture investigation only.
// Deterministic, Ollama-free tests for the B+C contradiction policies in
// `V1_4B_PolicyExperiments.swift`, plus additional V1.4B-required coverage
// (higher ordinals, unique-target discriminator omission, immutable-source
// multi-edit composition). Run via
// `scripts/test_v1_4b_experimental_policies.sh`.

private func expectSuccess(
    _ result: Result<NSRange, ResolverFailure>,
    location: Int,
    length: Int,
    file: StaticString = #file,
    line: UInt = #line
) {
    switch result {
    case .success(let range):
        precondition(range.location == location && range.length == length, "unexpected range \(range)", file: file, line: line)
    case .failure(let failure):
        preconditionFailure("expected success, got \(failure)", file: file, line: line)
    }
}

@main
enum V14BResolverTests {
    static func main() {
        testUniqueTargetDiscriminatorOmitted()
        testRepeatedTargetRequiresDiscriminator()
        testHigherOccurrenceOrdinals()
        testBCAgreementAllThreePolicies()
        testBCContradictionP1RejectsP2AcceptsP3Rejects()
        testOccurrenceValidContextInvalid()
        testContextValidOccurrenceInvalid()
        testBothInvalid()
        testImmutableSourceMultiEditComposition()
        print("All V1.4B policy/resolver checks passed.")
    }

    // A unique target needs no discriminator at all -- Candidate A already
    // resolves it; B/C fields, if simply absent, must not be required.
    static func testUniqueTargetDiscriminatorOmitted() {
        let source = "The witness confirmed the statement." as NSString
        let ref = ModelFacingReference.replace("confirmed") // no occurrence, no context
        expectSuccess(resolveReference(ref, in: source), location: 12, length: 9)
    }

    // The same sourceText, now repeated, MUST fail without a discriminator
    // -- re-confirms V1.4's core finding as a regression guard for V1.4B's
    // new code, not a re-litigation of it.
    static func testRepeatedTargetRequiresDiscriminator() {
        let source = "the accused said the accused left" as NSString
        guard case .failure(.ambiguousOccurrences(2)) = resolveReference(.replace("the accused"), in: source) else {
            preconditionFailure("expected repeated target with no discriminator to fail closed")
        }
    }

    // Higher ordinals (up to 10), a repetition level V1.4 did not exercise.
    static func testHigherOccurrenceOrdinals() {
        let source = Array(repeating: "the item", count: 10).joined(separator: ", ") as NSString
        let occurrences = findExactOccurrences(of: "the item", in: source)
        precondition(occurrences.count == 10, "expected exactly 10 occurrences, got \(occurrences.count)")
        expectSuccess(
            resolveReference(.replace("the item", occurrence: 7), in: source),
            location: occurrences[6].location,
            length: occurrences[6].length
        )
        expectSuccess(
            resolveReference(.replace("the item", occurrence: 10), in: source),
            location: occurrences[9].location,
            length: occurrences[9].length
        )
    }

    // All three policies must agree when occurrence and context genuinely
    // point to the same location -- the policies should only diverge on
    // disagreement, not on ordinary agreement.
    static func testBCAgreementAllThreePolicies() {
        let source = "the accused said the accused left" as NSString
        let ref = ModelFacingReference.replace("the accused", occurrence: 2, rightContext: " left")
        for policy in [resolveBCPolicyP1StrictAgreement, resolveBCPolicyP2OccurrencePrimary, resolveBCPolicyP3Fallback] {
            guard case .resolved(let range) = policy(ref, source) else {
                preconditionFailure("expected agreement to resolve under every policy")
            }
            precondition(range.location == 17 && range.length == 11, "unexpected range \(range)")
        }
    }

    // A genuine contradiction: occurrence says "2nd", context uniquely
    // identifies a DIFFERENT occurrence (the 1st, via context that only
    // matches the first). P1 must reject; P3 (as implemented -- both
    // individually valid but disagreeing) must also reject rather than
    // guess; P2 (occurrence-primary) resolves to occurrence's answer
    // despite the disagreement -- this is exactly the risk P2 exists to
    // expose, not evidence P2 should be adopted.
    static func testBCContradictionP1RejectsP2AcceptsP3Rejects() {
        let source = "the accused said, the accused left" as NSString
        // occurrence=2 -> second "the accused" (after the comma).
        // rightContext=" said" only matches the FIRST occurrence.
        let ref = ModelFacingReference.replace("the accused", occurrence: 2, rightContext: " said")

        guard case .rejectedContradiction = resolveBCPolicyP1StrictAgreement(ref, in: source) else {
            preconditionFailure("expected P1 to reject a genuine contradiction")
        }
        guard case .resolved(let p2Range) = resolveBCPolicyP2OccurrencePrimary(ref, in: source) else {
            preconditionFailure("expected P2 to resolve via occurrence despite disagreement")
        }
        // P2 resolved to occurrence's target (2nd), NOT context's target
        // (1st) -- demonstrating the exact silent-mistargeting risk P2
        // carries when the model's two discriminators disagree.
        let occurrences = findExactOccurrences(of: "the accused", in: source)
        precondition(p2Range == occurrences[1], "expected P2 to resolve to the occurrence-indicated (2nd) target")
        guard case .rejectedContradiction = resolveBCPolicyP3Fallback(ref, in: source) else {
            preconditionFailure("expected P3 to also reject a genuine both-valid contradiction")
        }
    }

    static func testOccurrenceValidContextInvalid() {
        let source = "the accused said the accused left" as NSString
        // occurrence=1 is valid; rightContext is wrong for occurrence 1
        // (real text is " said", claimed is " departed").
        let ref = ModelFacingReference.replace("the accused", occurrence: 1, rightContext: " departed")
        guard case .rejectedContextInvalidOnly = resolveBCPolicyP1StrictAgreement(ref, in: source) else {
            preconditionFailure("expected P1 to reject when context alone is invalid")
        }
        guard case .resolved = resolveBCPolicyP2OccurrencePrimary(ref, in: source) else {
            preconditionFailure("expected P2 to still resolve via valid occurrence")
        }
        guard case .resolved(let p3Range) = resolveBCPolicyP3Fallback(ref, in: source) else {
            preconditionFailure("expected P3 to fall back to the valid occurrence")
        }
        precondition(p3Range == findExactOccurrences(of: "the accused", in: source)[0])
    }

    static func testContextValidOccurrenceInvalid() {
        let source = "the accused said the accused left" as NSString
        // occurrence=5 is out of range (only 2 occurrences); rightContext
        // " left" correctly identifies the 2nd occurrence uniquely.
        let ref = ModelFacingReference.replace("the accused", occurrence: 5, rightContext: " left")
        guard case .rejectedOccurrenceInvalidOnly = resolveBCPolicyP1StrictAgreement(ref, in: source) else {
            preconditionFailure("expected P1 to reject when occurrence alone is invalid")
        }
        guard case .rejectedOccurrenceInvalidOnly = resolveBCPolicyP2OccurrencePrimary(ref, in: source) else {
            preconditionFailure("expected P2 (occurrence-primary) to reject when its primary discriminator is invalid, even though context alone would have resolved")
        }
        guard case .resolved(let p3Range) = resolveBCPolicyP3Fallback(ref, in: source) else {
            preconditionFailure("expected P3 to fall back to the valid context")
        }
        precondition(p3Range == findExactOccurrences(of: "the accused", in: source)[1])
    }

    static func testBothInvalid() {
        let source = "the accused said the accused left" as NSString
        let ref = ModelFacingReference.replace("the accused", occurrence: 9, rightContext: " nonexistent")
        guard case .rejectedBothInvalid = resolveBCPolicyP1StrictAgreement(ref, in: source) else {
            preconditionFailure("expected P1 to report both-invalid")
        }
        guard case .rejectedBothInvalid = resolveBCPolicyP3Fallback(ref, in: source) else {
            preconditionFailure("expected P3 to report both-invalid")
        }
        // P2 is occurrence-primary: once occurrence itself fails, it never
        // evaluates context at all -- so in this specific both-invalid
        // case it still reports the narrower "occurrence invalid" reason,
        // not "both invalid". This is a real, observed property of P2's
        // design (it collapses "both invalid" into "occurrence invalid"
        // whenever occurrence fails first), not a test defect.
        guard case .rejectedOccurrenceInvalidOnly = resolveBCPolicyP2OccurrencePrimary(ref, in: source) else {
            preconditionFailure("expected P2 to report occurrence-invalid-only even when context is also invalid")
        }
    }

    // Immutable-source composition for a two-edit batch where each item
    // supplies its own occurrence discriminator -- confirms per-item B/C
    // fields compose correctly under the same immutable-source guarantee
    // V1.4 already proved structurally.
    static func testImmutableSourceMultiEditComposition() {
        let source = "the witness confirmed it. the accused denied it. the witness later recanted." as NSString
        let proposals = [
            ModelFacingProposal(id: "p1", reference: .replace("the witness", occurrence: 1), replacementText: "The witness"),
            ModelFacingProposal(id: "p2", reference: .replace("the accused"), replacementText: "The accused"),
        ]
        let forward = resolveBatch(proposals, against: source)
        let reversed = resolveBatch(proposals.reversed(), against: source)
        func range(_ results: [(proposal: ModelFacingProposal, result: Result<NSRange, ResolverFailure>)], _ id: String) -> NSRange? {
            guard let match = results.first(where: { $0.proposal.id == id }), case .success(let r) = match.result else { return nil }
            return r
        }
        precondition(range(forward, "p1") == range(reversed, "p1"))
        precondition(range(forward, "p2") == range(reversed, "p2"))
        precondition(range(forward, "p1")?.location == 0)
    }
}
