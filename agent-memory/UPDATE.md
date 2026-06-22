# agent-memory — Update migrations

Migration log for `/agent-memory update`. One section per released version, newest
at the bottom. Each line is a single change tagged `safe` or `sensitive`:

- `safe` — pure addition or a scaffolding change with no user content at risk.
  `update` may apply it automatically.
- `sensitive` — touches a file that can hold user content, or renames/moves/
  deletes anything. `update` must show a diff and get confirmation first.

Format:

```md
## <version>
- safe: <change>
- sensitive: <change>
```

---

## 0.0.1

- safe: initial baseline — no migrations.
