# Your Data Is Not Just Stored. It Is Distilled.

The new extraction is not copying your file. It is learning from your life.

Users produce text, photos, clicks, voice, documents, behavior, and social graphs. Companies can convert those signals into models, recommendations, moderation systems, fraud scores, ads, and automation.

Deleting a database row may not remove the influence that row already had on a model, ranking system, risk score, or profile.

> Mental model: AI extraction can turn a file into influence that no longer looks like a file.

## Extraction layers

- raw data
- embeddings
- labels
- preference profiles
- moderation rules
- fraud models
- recommendation models
- ad targeting

Each layer is farther from the original file and harder for the user to see. A photo may become labels. Labels may become a profile. The profile may affect ranking, moderation, fraud review, prices, or recommendations. By the time the user asks "delete my photo," the system may already have used it to shape other decisions.

## The new copy problem

Old copying was visible:

```text
file -> duplicate file
```

Model extraction is different:

```text
file -> embedding -> cluster -> score -> policy
```

The copied thing is no longer a file the user can point at. It is influence inside another system.

That does not mean every model use is evil. Local search, accessibility, spam filtering, translation, and personal assistants can be genuinely useful. The question is authority: who chooses the learning, who can inspect it, and who benefits from the result?

## Better AI boundary

Personal data should first become personal memory:

- local embeddings
- local indexes
- user-held context
- explicit export
- narrow remote tasks
- visible retention
- revocable tool access

The assistant should work for the user, not quietly turn the user into training material.

## Interactive model

[[demo:post_model]]

Extraction map: drop in a message, photo, click, and location event. The demo shows which derived systems may learn from each input.

## Main lesson

AI makes data extraction less visible. The copied artifact may disappear while the learned influence remains.

## EdgeRun seed

Personal AI should run under user authority. Training, indexing, embeddings, and memory should be local-first unless the user explicitly grants a narrow capability.
