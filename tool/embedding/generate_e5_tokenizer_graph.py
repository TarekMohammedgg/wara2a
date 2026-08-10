#!/usr/bin/env python3
"""Generate and parity-check Wara2a's pinned multilingual-E5 tokenizer graph.

This script intentionally generates only the tokenizer/pre-processing graph.
Embedding weights remain an explicitly installed external artifact.

The graph is produced by ONNX Runtime Extensions' official Hugging Face
converter. Its SentencepieceTokenizer node embeds the exact SentencePiece
bytes from the pinned upstream revision, so Android does not need Python,
Transformers, network access, or a separately implemented tokenizer.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any, Iterable

import numpy as np
import onnx
import onnxruntime as ort
from onnx import numpy_helper
from onnxruntime_extensions import gen_processing_models, get_library_path
from transformers import AutoTokenizer


REPOSITORY = "intfloat/multilingual-e5-small"
REVISION = "614241f622f53c4eeff9890bdc4f31cfecc418b3"
SENTENCEPIECE_BYTES = 5_069_051
SENTENCEPIECE_SHA256 = (
    "cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865"
)
DEFAULT_OUTPUT = Path(
    "android/app/src/main/assets/embedding/"
    "multilingual_e5_small_tokenizer.onnx"
)
DEFAULT_CORPUS = Path(
    "test/fixtures/search/semantic_retrieval_evaluation_v1.json"
)

_COHORT = (
    "query: فاتورة الغسالة من توكيل العربي",
    "query: office chair receipt",
    "query: Samsung S25 Ultra فاتورة Vodafone",
    "passage: صيدليات العزبي\nOmron blood pressure monitor\n2026-02-14",
    "passage: IKEA Cairo\noffice chair\nEGP 7499.00",
    "passage: Carrefour\nفاتورة AirPods Pro\n2026-03-01",
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _verify_sentencepiece(tokenizer: Any) -> bytes:
    vocab_file = getattr(tokenizer, "vocab_file", None)
    if not vocab_file:
        raise RuntimeError("The pinned tokenizer did not expose a SentencePiece file")
    data = Path(vocab_file).read_bytes()
    digest = _sha256(data)
    if len(data) != SENTENCEPIECE_BYTES or digest != SENTENCEPIECE_SHA256:
        raise RuntimeError(
            "Pinned SentencePiece artifact mismatch: "
            f"bytes={len(data)}, sha256={digest}"
        )
    return data


def _tokenizer_node(model: onnx.ModelProto) -> onnx.NodeProto:
    matches = [
        node
        for node in model.graph.node
        if node.domain == "ai.onnx.contrib"
        and node.op_type == "SentencepieceTokenizer"
    ]
    if len(matches) != 1:
        raise RuntimeError(
            "Expected exactly one ai.onnx.contrib::SentencepieceTokenizer; "
            f"found {len(matches)}"
        )
    return matches[0]


def _verify_embedded_model(model: onnx.ModelProto, expected: bytes) -> None:
    node = _tokenizer_node(model)
    attributes = {attribute.name: attribute for attribute in node.attribute}
    embedded = attributes.get("model")
    if embedded is None or embedded.s != expected:
        raise RuntimeError("Tokenizer graph does not embed the pinned SentencePiece bytes")

    initializers = {
        initializer.name: numpy_helper.to_array(initializer).tolist()
        for initializer in model.graph.initializer
    }
    for name, expected_value in (
        ("add_bos", [True]),
        ("add_eos", [True]),
        ("reverse", [False]),
        ("fairseq", [True]),
    ):
        actual_value = initializers.get(name)
        if actual_value != expected_value:
            raise RuntimeError(
                f"Tokenizer graph input {name!r} must equal {expected_value}; "
                f"got {actual_value}"
            )


def _iter_string_values(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        cleaned = value.strip()
        if cleaned:
            yield cleaned
    elif isinstance(value, dict):
        for nested in value.values():
            yield from _iter_string_values(nested)
    elif isinstance(value, list):
        for nested in value:
            yield from _iter_string_values(nested)


def _fixture_texts(path: Path) -> list[str]:
    if not path.is_file():
        raise FileNotFoundError(f"Evaluation corpus is missing: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    texts: list[str] = []

    def visit(value: Any, key: str | None = None) -> None:
        if isinstance(value, dict):
            for nested_key, nested_value in value.items():
                if nested_key == "query" and isinstance(nested_value, str):
                    texts.append(f"query: {nested_value.strip()}")
                elif nested_key == "corpus" and isinstance(nested_value, list):
                    for document in nested_value:
                        fields = list(_iter_string_values(document))
                        if fields:
                            texts.append("passage: " + "\n".join(fields))
                visit(nested_value, nested_key)
        elif isinstance(value, list):
            for nested in value:
                visit(nested, key)

    visit(payload)
    # Preserve order while removing duplicates introduced by nested fixtures.
    return list(dict.fromkeys((*_COHORT, *texts)))


def _as_int_list(value: Any, name: str) -> list[int]:
    array = np.asarray(value)
    if array.ndim != 1:
        raise RuntimeError(f"Tokenizer output {name!r} must be flat, got {array.shape}")
    return [int(item) for item in array.tolist()]


def _parity_check(
    graph_path: Path,
    tokenizer: Any,
    texts: Iterable[str],
) -> tuple[int, int]:
    options = ort.SessionOptions()
    options.register_custom_ops_library(get_library_path())
    session = ort.InferenceSession(
        str(graph_path),
        sess_options=options,
        providers=["CPUExecutionProvider"],
    )
    input_names = [entry.name for entry in session.get_inputs()]
    if input_names != ["inputs"]:
        raise RuntimeError(f"Unexpected tokenizer graph inputs: {input_names}")
    output_names = [entry.name for entry in session.get_outputs()]
    expected_outputs = ["tokens", "instance_indices", "token_indices"]
    if output_names != expected_outputs:
        raise RuntimeError(f"Unexpected tokenizer graph outputs: {output_names}")

    checked = 0
    maximum_tokens = 0
    for text in texts:
        expected = tokenizer(
            text,
            add_special_tokens=True,
            truncation=False,
            return_attention_mask=False,
            return_token_type_ids=False,
        )["input_ids"]
        outputs = session.run(None, {"inputs": np.asarray([text], dtype=object)})
        actual = _as_int_list(outputs[0], "tokens")
        instances = _as_int_list(outputs[1], "instance_indices")
        positions = _as_int_list(outputs[2], "token_indices")
        if actual != expected:
            raise RuntimeError(
                "Tokenizer parity failed for "
                f"{text!r}: expected={expected}, actual={actual}"
            )
        # For a one-element batch ORT Extensions returns CSR-style segment
        # boundaries [0, token_count], not one instance id per token.
        if instances != [0, len(actual)]:
            raise RuntimeError(f"Unexpected instance indices for {text!r}: {instances}")
        # token_indices are UTF-8/tokenizer source offsets. Special tokens can
        # share offset zero, so only their deterministic shape/order matters
        # to this bridge (the encoder consumes token IDs, not source offsets).
        if len(positions) != len(actual) or positions != sorted(positions):
            raise RuntimeError(f"Unexpected token indices for {text!r}: {positions}")
        checked += 1
        maximum_tokens = max(maximum_tokens, len(actual))
    return checked, maximum_tokens


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--corpus",
        type=Path,
        action="append",
        default=None,
        help="JSON corpus to include in exact token-id parity checks (repeatable)",
    )
    arguments = parser.parse_args()

    tokenizer = AutoTokenizer.from_pretrained(
        REPOSITORY,
        revision=REVISION,
        use_fast=False,
    )
    sentencepiece = _verify_sentencepiece(tokenizer)
    graph, _ = gen_processing_models(tokenizer, pre_kwargs={})
    _verify_embedded_model(graph, sentencepiece)

    # Strip mutable or machine-specific metadata and set an explicit producer.
    graph.producer_name = "Wara2a / onnxruntime-extensions"
    graph.producer_version = "0.13.0"
    graph.domain = "com.wara2a.embedding"
    graph.model_version = 1
    del graph.metadata_props[:]

    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    onnx.save_model(graph, arguments.output)
    persisted = arguments.output.read_bytes()
    reparsed = onnx.load_model_from_string(persisted)
    onnx.checker.check_model(reparsed, full_check=True)
    _verify_embedded_model(reparsed, sentencepiece)

    corpus_paths = arguments.corpus or [DEFAULT_CORPUS]
    parity_texts: list[str] = list(_COHORT)
    for path in corpus_paths:
        parity_texts.extend(_fixture_texts(path))
    parity_texts = list(dict.fromkeys(parity_texts))
    checked, maximum_tokens = _parity_check(
        arguments.output,
        tokenizer,
        parity_texts,
    )

    print(
        json.dumps(
            {
                "repository": REPOSITORY,
                "revision": REVISION,
                "sentencepieceBytes": len(sentencepiece),
                "sentencepieceSha256": _sha256(sentencepiece),
                "graphPath": str(arguments.output),
                "graphBytes": len(persisted),
                "graphSha256": _sha256(persisted),
                "paritySamples": checked,
                "maximumTokensObserved": maximum_tokens,
            },
            indent=2,
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
