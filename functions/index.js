/**
 * リマインド通知（Step6 仕様書 3章・6章）
 *
 * 15分おきに、FCM トークンを持つユーザーごとに、自分のライブ一覧の受付の
 * 「次の締切」を調べ、1日前・3時間前に Web プッシュを送る。
 * 次の締切の規則は lib/utils/deadline.dart の nextDeadlineOf、
 * 当選者のみの受付の条件は lib/utils/winners_only.dart と同じ。
 */
const {setGlobalOptions} = require("firebase-functions/v2");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {defineSecret} = require("firebase-functions/params");
const {findPrefecture} = require("./prefectures");

const WEATHER_API_KEY = defineSecret("WEATHER_API_KEY");

initializeApp();
setGlobalOptions({region: "asia-northeast1", maxInstances: 1});

/** 公開先の URL（通知を押したときに開く。秘密ではない） */
const APP_URL = "https://oshiashi-test.web.app";

const HOUR = 60 * 60 * 1000;

/** 締切の種類の名前（DeadlineKind.label と同じ） */
const KIND_LABEL = {
  apply: "申込期限",
  result: "当落発表",
  payment: "入金期限",
};

/** 無効なトークンのエラー（fcmTokens から消す） */
const INVALID_TOKEN_ERRORS = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/** Firestore の値を Date に（無ければ null） */
function toDate(value) {
  return value && typeof value.toDate === "function" ? value.toDate() : null;
}

/**
 * 受付1件の次の締切（nextDeadlineOf と同じ規則）。
 * 未申込（不明な値も含む）→ 申込期限、申込済 → 当落発表、当選 → 入金期限、
 * 落選・入金済 → なし。日時が無ければ null。
 */
function nextDeadline(reception, status) {
  let kind;
  let at;
  if (status === "applied") {
    kind = "result";
    at = toDate(reception.resultAt);
  } else if (status === "won") {
    kind = "payment";
    at = toDate(reception.paymentDeadline);
  } else if (status === "lost" || status === "paid") {
    return null;
  } else {
    kind = "apply";
    at = toDate(reception.applyEndAt);
  }
  return at ? {kind, at} : null;
}

/** 残り時間から段階を決める（Step6 仕様書 3.2）。対象外は null */
function stageOf(remainingMs) {
  if (remainingMs <= 0) return null;
  if (remainingMs <= 3 * HOUR) return "3h";
  if (remainingMs <= 24 * HOUR) return "1d";
  return null;
}

/** 日本時間で「11/9(月) 23:59」の形にする */
function formatAt(date) {
  const parts = new Intl.DateTimeFormat("ja-JP", {
    timeZone: "Asia/Tokyo",
    month: "numeric",
    day: "numeric",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const get = (type) => parts.find((p) => p.type === type)?.value ?? "";
  return `${get("month")}/${get("day")}(${get("weekday")}) ` +
    `${get("hour")}:${get("minute")}`;
}

/** 配列を size 件ずつに分ける（Firestore の in は30件まで） */
function chunk(list, size) {
  const result = [];
  for (let i = 0; i < list.length; i += size) {
    result.push(list.slice(i, i + size));
  }
  return result;
}

/**
 * 申込開始の通知（add_S 3.1）。未申込（申込状況が無い）で、
 * 申込開始まで1時間以内なら {at}。それ以外は null
 */
function startNotice(reception, status, now) {
  if (status !== undefined) return null;
  const at = toDate(reception.applyStartAt);
  if (!at) return null;
  const remaining = at.getTime() - now.getTime();
  return remaining > 0 && remaining <= HOUR ? {at} : null;
}

/**
 * 通知の題名に入れる推しの情報（add_S 3.2）。
 * フォロー中の推し・最推し・絵文字と、ライブに出てくるフォロー中の推しの名前
 */
async function loadOshiContext(db, userRef, liveOf) {
  const settings = userRef.collection("settings");
  const [userSnap, favSnap, emojiSnap] = await Promise.all([
    userRef.get(),
    settings.doc("favoriteOshi").get(),
    settings.doc("oshiEmojis").get(),
  ]);
  const user = userSnap.data() ?? {};
  const listOf = (v) => (Array.isArray(v) ? v : []);
  const followingGroups = new Set(listOf(user.followingGroupIds));
  const followingOshis = new Set(listOf(user.followingOshiIds));
  const fav = favSnap.data();
  const favoriteKey = fav && typeof fav.kind === "string" &&
    typeof fav.id === "string" ? `${fav.kind}:${fav.id}` : null;
  const emojis = emojiSnap.data()?.emojis ?? {};

  // ライブに出てくるフォロー中の推しだけ、名前を読む
  const refs = new Map();
  for (const live of liveOf.values()) {
    for (const id of listOf(live.groupIds)) {
      if (followingGroups.has(id)) {
        refs.set(`group:${id}`, db.collection("groups").doc(id));
      }
    }
    for (const id of listOf(live.oshiIds)) {
      if (followingOshis.has(id)) {
        refs.set(`person:${id}`, db.collection("oshis").doc(id));
      }
    }
  }
  const names = new Map();
  if (refs.size > 0) {
    const keys = [...refs.keys()];
    const snaps = await db.getAll(...refs.values());
    snaps.forEach((s, i) => {
      const name = s.exists ? s.data().name : null;
      if (typeof name === "string" && name.trim()) {
        names.set(keys[i], name.trim());
      }
    });
  }
  return {followingGroups, followingOshis, favoriteKey, emojis, names};
}

/**
 * ライブの推しの【】（add_S 3.2）。例：「【🌙星宮ルナ】」。
 * 最推しが入っていれば最推し、無ければ個人 → グループの順の最初の1つ。
 * フォロー中の推しがいなければ ""
 */
function oshiPrefix(live, ctx) {
  if (!live) return "";
  const listOf = (v) => (Array.isArray(v) ? v : []);
  const keys = [
    ...listOf(live.oshiIds)
        .filter((id) => ctx.followingOshis.has(id))
        .map((id) => `person:${id}`),
    ...listOf(live.groupIds)
        .filter((id) => ctx.followingGroups.has(id))
        .map((id) => `group:${id}`),
  ].filter((k) => ctx.names.has(k));
  if (keys.length === 0) return "";
  const key = keys.includes(ctx.favoriteKey) ? ctx.favoriteKey : keys[0];
  const emoji = typeof ctx.emojis[key] === "string" ? ctx.emojis[key] : "";
  return `【${emoji}${ctx.names.get(key)}】`;
}

/**
 * トークンへ送り、無効なトークンを fcmTokens から消す（Step6 6.2・add_S）。
 * [path] は押したときに開くアプリのパス（data.path にも入れる）。
 * 残ったトークンと、送れた件数を返す
 */
async function sendToTokens(messaging, userRef, tokens, {title, body, path, data}) {
  const res = await messaging.sendEachForMulticast({
    tokens,
    notification: {title, body},
    data: {...data, path},
    webpush: {
      notification: {icon: `${APP_URL}/icons/Icon-192.png`},
      fcmOptions: {link: `${APP_URL}${path}`},
    },
  });
  const invalid = [];
  res.responses.forEach((resp, i) => {
    if (!resp.success && INVALID_TOKEN_ERRORS.has(resp.error?.code)) {
      invalid.push(tokens[i]);
    }
  });
  for (const token of invalid) {
    await userRef.collection("fcmTokens").doc(token).delete();
  }
  return {
    tokens: tokens.filter((t) => !invalid.includes(t)),
    successCount: res.successCount,
  };
}

/**
 * ユーザー1人分を調べて送る。送った件数を返す。
 * 受付ごとに、申込開始（add_S 3.1）と次の締切（Step6 3.2）を調べ、
 * 題名の先頭にライブの推しを入れる（add_S 3.2）
 */
async function remindUser(db, messaging, uid, tokens, now) {
  const userRef = db.collection("users").doc(uid);

  const myLivesSnap = await userRef.collection("myLives").get();
  const liveIds = myLivesSnap.docs.map((d) => d.id);
  if (liveIds.length === 0) return 0;

  const appsSnap = await userRef.collection("applications").get();
  const statusOf = new Map();
  const winnerLiveIds = new Set();
  for (const d of appsSnap.docs) {
    const {status, liveId} = d.data();
    statusOf.set(d.id, status);
    if ((status === "won" || status === "paid") && typeof liveId === "string") {
      winnerLiveIds.add(liveId);
    }
  }

  const receptions = [];
  for (const ids of chunk(liveIds, 30)) {
    const snap = await db.collection("receptions")
        .where("liveId", "in", ids).get();
    receptions.push(...snap.docs);
  }
  if (receptions.length === 0) return 0;

  const liveSnaps = await db.getAll(
      ...liveIds.map((id) => db.collection("lives").doc(id)));
  const liveOf = new Map(
      liveSnaps.filter((s) => s.exists).map((s) => [s.id, s.data()]));
  const ctx = await loadOshiContext(db, userRef, liveOf);

  let sent = 0;
  for (const doc of receptions) {
    if (tokens.length === 0) break;
    const r = doc.data();
    // 当選者のみの受付は、そのライブで当選している人だけ（isReceptionVisible）
    if (r.winnersOnly === true && !winnerLiveIds.has(r.liveId)) continue;

    const status = statusOf.get(doc.id);
    const live = liveOf.get(r.liveId);
    const liveTitle = live?.title ?? "ライブ";
    const prefix = oshiPrefix(live, ctx);

    // 送る候補（申込開始・次の締切）
    const notices = [];
    const start = startNotice(r, status, now);
    if (start) {
      notices.push({
        kind: "start",
        stage: "1h",
        at: start.at,
        title: `${prefix}まもなく申込開始`,
        body: `${liveTitle}（${r.name}）\n${formatAt(start.at)} から`,
      });
    }
    const deadline = nextDeadline(r, status);
    if (deadline) {
      const remaining = deadline.at.getTime() - now.getTime();
      const stage = stageOf(remaining);
      if (stage) {
        const hours = Math.ceil(remaining / HOUR);
        notices.push({
          kind: deadline.kind,
          stage,
          at: deadline.at,
          title: `${prefix}${KIND_LABEL[deadline.kind]}まで あと${hours}時間`,
          body: `${liveTitle}（${r.name}）\n${formatAt(deadline.at)} まで`,
        });
      }
    }

    for (const n of notices) {
      if (tokens.length === 0) break;
      const sentRef = userRef.collection("sentNotifications")
          .doc(`${doc.id}_${n.kind}_${n.stage}`);
      if ((await sentRef.get()).exists) continue;

      const result = await sendToTokens(messaging, userRef, tokens, {
        title: n.title,
        body: n.body,
        path: `/lives/${r.liveId}`,
        data: {liveId: r.liveId},
      });
      tokens = result.tokens;

      await sentRef.set({
        receptionId: doc.id,
        kind: n.kind,
        stage: n.stage,
        deadlineAt: Timestamp.fromDate(n.at),
        sentAt: FieldValue.serverTimestamp(),
      });
      sent += result.successCount;
    }
  }
  return sent;
}

exports.sendDeadlineReminders = onSchedule(
    {schedule: "every 15 minutes", timeZone: "Asia/Tokyo"},
    async () => {
      const db = getFirestore();
      const messaging = getMessaging();
      const now = new Date();

      // FCM トークンを uid ごとにまとめる
      const tokenSnap = await db.collectionGroup("fcmTokens").get();
      const tokensByUid = new Map();
      for (const d of tokenSnap.docs) {
        const uid = d.ref.parent.parent.id;
        if (!tokensByUid.has(uid)) tokensByUid.set(uid, []);
        tokensByUid.get(uid).push(d.id);
      }

      let total = 0;
      for (const [uid, tokens] of tokensByUid) {
        try {
          total += await remindUser(db, messaging, uid, tokens, now);
        } catch (e) {
          // 1人の失敗で全体を止めない
          logger.error(`ユーザー ${uid} の通知に失敗しました`, e);
        }
      }
      logger.info(`リマインド通知: ユーザー ${tokensByUid.size} 人、送信 ${total} 件`);
    },
);

// ---------------------------------------------------------------------------
// 公演の日の天気（add_E 5章）
// ---------------------------------------------------------------------------

/** 天気のキャッシュを使う時間（3時間） */
const WEATHER_CACHE_MS = 3 * HOUR;

/** 2桁にする */
function pad2(n) {
  return String(n).padStart(2, "0");
}

/** 数なら整数に丸める。数でなければ null */
function roundOrNull(v) {
  return typeof v === "number" && Number.isFinite(v) ? Math.round(v) : null;
}

/**
 * 都道府県の10日分の予報（日ごとの要約）を返す。
 * weatherCache/pref-{code} に3時間置き、それより新しければ Weather API を呼ばない
 */
async function loadForecastDays(db, pref) {
  const ref = db.collection("weatherCache").doc(`pref-${pref.code}`);
  const snap = await ref.get();
  if (snap.exists) {
    const cached = snap.data();
    const fetchedAt = cached.fetchedAt?.toMillis?.() ?? 0;
    if (Date.now() - fetchedAt < WEATHER_CACHE_MS && Array.isArray(cached.days)) {
      return cached.days;
    }
  }

  const params = new URLSearchParams({
    "key": WEATHER_API_KEY.value(),
    "location.latitude": String(pref.lat),
    "location.longitude": String(pref.lng),
    "days": "10",
    "pageSize": "10",
    "languageCode": "ja",
  });
  const res = await fetch(
      `https://weather.googleapis.com/v1/forecast/days:lookup?${params}`);
  if (!res.ok) {
    logger.error(`Weather API の呼び出しに失敗しました: ${res.status}`,
        await res.text());
    throw new HttpsError("internal", "天気を取得できませんでした");
  }
  const json = await res.json();
  // displayDate はその場所の日付（日本なら日本時間）。
  // 日本（ウェザーニューズ社のデータ）は昼の予報 daytimeForecast が無く、
  // 1日全体の予報 fullDayForecast で返るので、そちらを使う
  const days = (json.forecastDays ?? []).map((d) => {
    const date = d.displayDate ?? {};
    const forecast = d.daytimeForecast ?? d.fullDayForecast ?? {};
    // 説明の末尾の「（夜間）」などのかっこ書きは外す
    const text = (forecast.weatherCondition?.description?.text ?? "")
        .replace(/[（(][^）)]*[）)]$/, "")
        .trim();
    return {
      date: `${date.year}-${pad2(date.month)}-${pad2(date.day)}`,
      type: forecast.weatherCondition?.type ?? "TYPE_UNSPECIFIED",
      text,
      maxC: roundOrNull(d.maxTemperature?.degrees),
      minC: roundOrNull(d.minTemperature?.degrees),
      rainPercent: forecast.precipitation?.probability?.percent ?? null,
    };
  });
  await ref.set({
    prefecture: pref.name,
    fetchedAt: FieldValue.serverTimestamp(),
    days,
  });
  return days;
}

/**
 * 公演の日の天気（Callable）。
 * 入力：{prefecture: "東京都", date: "2026-11-09"}
 * 出力：{status: "ok", date, type, text, maxC, minC, rainPercent}
 *      または {status: "outOfRange" | "unknownPlace", date}
 */
exports.getEventWeather = onCall(
    {secrets: [WEATHER_API_KEY]},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "ログインしてください");
      }
      const {prefecture, date} = request.data ?? {};
      if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
        throw new HttpsError("invalid-argument", "日付が正しくありません");
      }
      const pref = findPrefecture(prefecture);
      if (!pref) return {status: "unknownPlace", date};

      const days = await loadForecastDays(getFirestore(), pref);
      const day = days.find((d) => d.date === date);
      if (!day) return {status: "outOfRange", date};
      return {status: "ok", ...day};
    },
);

// ---------------------------------------------------------------------------
// 新しいマッチの通知（add_S 3.3）
// ---------------------------------------------------------------------------

/** 配列にする（配列でなければ空） */
function arrayOf(v) {
  return Array.isArray(v) ? v : [];
}

/** 2つの配列に共通の値があるか */
function intersects(a, b) {
  const set = new Set(arrayOf(b));
  return arrayOf(a).some((v) => set.has(v));
}

/** 2つの配列の中身が同じか（順は問わない） */
function sameSet(a, b) {
  const x = new Set(arrayOf(a));
  const y = new Set(arrayOf(b));
  return x.size === y.size && [...x].every((v) => y.has(v));
}

/**
 * 交換の投稿が募集中になった・譲や求が変わったときに、
 * 相互マッチした相手の投稿の持ち主に通知する（相互マッチだけ）
 */
exports.notifyNewMatches = onDocumentWritten(
    "tradePosts/{postId}",
    async (event) => {
      const beforeSnap = event.data?.before;
      const afterSnap = event.data?.after;
      const before = beforeSnap?.exists ? beforeSnap.data() : null;
      const after = afterSnap?.exists ? afterSnap.data() : null;
      if (!after || after.status !== "open") return;

      // 新しく募集中になったか、譲・求が変わったときだけ
      const changed = !before ||
        before.status !== "open" ||
        !sameSet(before.giveKeys, after.giveKeys) ||
        !sameSet(before.wantKeys, after.wantKeys);
      if (!changed) return;

      const giveKeys = [...new Set(arrayOf(after.giveKeys))];
      const wantKeys = arrayOf(after.wantKeys);
      if (giveKeys.length === 0 || wantKeys.length === 0) return;

      const db = getFirestore();
      const messaging = getMessaging();
      const postId = event.params.postId;

      // この投稿の譲を求めている投稿（status はコードで絞る。インデックスを足さないため）
      const candidates = new Map();
      for (const keys of chunk(giveKeys, 30)) {
        const snap = await db.collection("tradePosts")
            .where("wantKeys", "array-contains-any", keys).get();
        for (const d of snap.docs) candidates.set(d.id, d);
      }

      // 相手（uid）ごとに、最初の相互マッチの投稿を1つ
      const firstByUid = new Map();
      for (const d of candidates.values()) {
        const theirs = d.data();
        if (d.id === postId || theirs.status !== "open") continue;
        if (typeof theirs.uid !== "string" || theirs.uid === after.uid) continue;
        // 相手の譲がこの投稿の求にも当たる（相互マッチ）
        if (!intersects(theirs.giveKeys, wantKeys)) continue;
        if (!firstByUid.has(theirs.uid)) firstByUid.set(theirs.uid, d.id);
      }

      let sent = 0;
      for (const [uid, theirPostId] of firstByUid) {
        try {
          const userRef = db.collection("users").doc(uid);
          const tokenSnap = await userRef.collection("fcmTokens").get();
          const tokens = tokenSnap.docs.map((t) => t.id);
          if (tokens.length === 0) continue;

          const sentRef = userRef.collection("sentNotifications")
              .doc(`match_${postId}_${theirPostId}`);
          if ((await sentRef.get()).exists) continue;

          const result = await sendToTokens(messaging, userRef, tokens, {
            title: "新しい相互マッチ",
            body: `${after.displayName ?? "だれか"}さんの投稿と、譲と求が合っています`,
            path: `/trade/${postId}?attach=${theirPostId}`,
            data: {postId, theirPostId},
          });
          await sentRef.set({
            postId,
            theirPostId,
            kind: "match",
            sentAt: FieldValue.serverTimestamp(),
          });
          sent += result.successCount;
        } catch (e) {
          // 1人の失敗で全体を止めない
          logger.error(`ユーザー ${uid} へのマッチの通知に失敗しました`, e);
        }
      }
      logger.info(
          `新しいマッチの通知: 投稿 ${postId}、相手 ${firstByUid.size} 人、送信 ${sent} 件`);
    },
);