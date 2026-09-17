//! The `template_library` table: a mirror of templates/library.yaml so the
//! list anyone can view is a plain table, refreshed on every startup.

use super::*;
use schlift::workout::v1::LibraryTemplate;

impl ServerDb {
    /// Replaces the table's contents with `entries`, in order. Entries that
    /// left the file are removed; users' copies are untouched.
    pub async fn sync_template_library(&self, entries: &[LibraryTemplate]) -> DbResult<()> {
        let now = now_unix();
        let mut tx = self.write_pool.begin().await?;
        let keep: Vec<String> = entries.iter().map(|e| e.id.clone()).collect();
        let placeholders = if keep.is_empty() {
            "''".to_string()
        } else {
            vec!["?"; keep.len()].join(", ")
        };
        let delete_sql = format!("DELETE FROM template_library WHERE id NOT IN ({placeholders})");
        let mut delete = sqlx::query(&delete_sql);
        for id in &keep {
            delete = delete.bind(id);
        }
        delete.execute(&mut *tx).await?;
        for (order, entry) in entries.iter().enumerate() {
            sqlx::query(
                "INSERT INTO template_library
                 (id, name, blurb, group_key, group_label, is_default, library_order, template_blob, updated_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                 ON CONFLICT(id) DO UPDATE SET
                   name = excluded.name,
                   blurb = excluded.blurb,
                   group_key = excluded.group_key,
                   group_label = excluded.group_label,
                   is_default = excluded.is_default,
                   library_order = excluded.library_order,
                   template_blob = excluded.template_blob,
                   updated_at = excluded.updated_at",
            )
            .bind(&entry.id)
            .bind(&entry.name)
            .bind(&entry.blurb)
            .bind(&entry.group_key)
            .bind(&entry.group_label)
            .bind(entry.is_default as i32)
            .bind(order as i64)
            .bind(entry.encode_to_vec())
            .bind(now)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    pub async fn list_template_library(&self) -> DbResult<Vec<LibraryTemplate>> {
        let rows = sqlx::query("SELECT template_blob FROM template_library ORDER BY library_order")
            .fetch_all(&self.read_pool)
            .await?;
        let mut out = Vec::with_capacity(rows.len());
        for row in rows {
            let blob: Vec<u8> = row.get("template_blob");
            out.push(LibraryTemplate::decode(blob.as_slice())?);
        }
        Ok(out)
    }
}
