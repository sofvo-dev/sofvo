/**
 * Sofvo App Review Notifier
 * ──────────────────────────────────────────────────────────────
 * info@sofvo.com に届く Apple / Google からの審査関連メールを
 * Gmail から拾って sofvo-dev/sofvo リポジトリに GitHub Issue を
 * 自動作成する Google Apps Script。
 *
 * セットアップ手順は scripts/apps-script/README.md を参照。
 */

const GITHUB_OWNER = 'sofvo-dev';
const GITHUB_REPO = 'sofvo';
const PROCESSED_LABEL = 'AppReview/Processed';
const ISSUE_LABELS = ['app-review'];

// 検索対象の送信元（Apple / Google Play）
const SENDER_QUERY = [
  'no_reply@email.apple.com',
  'noreply@email.apple.com',
  'googleplay-noreply@google.com',
  'googleplay-developer-noreply@google.com',
].map((addr) => `from:${addr}`).join(' OR ');

// 件名フィルタ（審査関連のみ拾う）
const SUBJECT_REGEX = /review|submission|rejected|approved|metadata|in review|ready for (sale|distribution)|your app|app store connect|google play/i;

function checkAppReviewEmails() {
  const token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) {
    throw new Error('GITHUB_TOKEN is not set. Add it under Project Settings → Script Properties.');
  }

  // 未処理の直近7日分のみ対象
  const query = `(${SENDER_QUERY}) -label:${PROCESSED_LABEL} newer_than:7d`;
  const threads = GmailApp.search(query);

  if (threads.length === 0) {
    console.log('No new review emails.');
    return;
  }

  // ラベル取得または作成
  let label = GmailApp.getUserLabelByName(PROCESSED_LABEL);
  if (!label) label = GmailApp.createLabel(PROCESSED_LABEL);

  let created = 0;
  let skipped = 0;

  for (const thread of threads) {
    const messages = thread.getMessages();
    for (const msg of messages) {
      const subject = msg.getSubject() || '';

      if (!SUBJECT_REGEX.test(subject)) {
        skipped++;
        continue;
      }

      const body = msg.getPlainBody() || '';
      const from = msg.getFrom();
      const date = msg.getDate();

      const issueTitle = `[App Review] ${subject}`.substring(0, 255);
      const issueBody = [
        `**From**: ${from}`,
        `**Date**: ${date.toISOString()}`,
        `**Subject**: ${subject}`,
        '',
        '---',
        '',
        body.substring(0, 8000), // GitHub Issue の本文上限に余裕を持たせる
      ].join('\n');

      const response = UrlFetchApp.fetch(
        `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues`,
        {
          method: 'post',
          contentType: 'application/json',
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
          payload: JSON.stringify({
            title: issueTitle,
            body: issueBody,
            labels: ISSUE_LABELS,
          }),
          muteHttpExceptions: true,
        }
      );

      const code = response.getResponseCode();
      if (code >= 200 && code < 300) {
        created++;
        console.log(`Created issue: ${issueTitle}`);
      } else {
        console.error(
          `Failed to create issue (HTTP ${code}): ${response.getContentText()}`
        );
        // 失敗したらラベルを付けずに次回リトライ対象のまま残す
        return;
      }
    }
    thread.addLabel(label);
  }

  console.log(`Done. Created: ${created}, Skipped: ${skipped}`);
}

/**
 * 手動テスト用: 最新1件だけ Issue 作成する（ラベルは付けない）
 */
function testCreateIssueFromLatest() {
  const token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) throw new Error('GITHUB_TOKEN not set');

  const threads = GmailApp.search(`(${SENDER_QUERY}) newer_than:30d`, 0, 1);
  if (threads.length === 0) {
    console.log('No matching emails found.');
    return;
  }
  const msg = threads[0].getMessages()[0];
  const subject = msg.getSubject();
  const body = msg.getPlainBody();

  const response = UrlFetchApp.fetch(
    `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues`,
    {
      method: 'post',
      contentType: 'application/json',
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github+json',
      },
      payload: JSON.stringify({
        title: `[App Review TEST] ${subject}`,
        body: `**TEST RUN**\n\n${body.substring(0, 8000)}`,
        labels: ISSUE_LABELS,
      }),
      muteHttpExceptions: true,
    }
  );
  console.log(`HTTP ${response.getResponseCode()}: ${response.getContentText().substring(0, 500)}`);
}
