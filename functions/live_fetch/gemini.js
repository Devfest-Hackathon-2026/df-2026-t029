/**
 * Gemini の呼び出し（add_L 3.5）。Vertex AI 経由（サービス アカウントの権限で呼ぶ）。
 * 1段目：Google 検索と URL コンテキストで公式サイトを調べ、文章で書き出す。
 * 2段目：その文章を add_L 3.3 の形（JSON）にする。
 */
const {GoogleGenAI} = require("@google/genai");

/** 使うモデル（add_L 3.5。Vertex AI で GA。リージョンは global） */
const GEMINI_MODEL = "gemini-3.8-flash";

/** ジャンルの日本語名（プロンプト用） */
const GENRE_LABEL = {
  idol: "アイドル",
  voice_actor: "声優",
  artist: "アーティスト",
  vtuber: "VTuber",
};

let client = null;

/** Gemini のクライアント（最初に使うときに作る） */
function ai() {
  if (!client) {
    const project = process.env.GCLOUD_PROJECT ??
      JSON.parse(process.env.FIREBASE_CONFIG ?? "{}").projectId;
    client = new GoogleGenAI({vertexai: true, project, location: "global"});
  }
  return client;
}

/** 日時の項目（日本時間）。[what] は何の日時か（欄の取り違えを防ぐため、欄ごとに説明を付ける。L-4c） */
function dateTime(what) {
  return {
    type: "string",
    description: `${what}。日本時間で YYYY-MM-DD または YYYY-MM-DDTHH:mm`,
  };
}

/** 2段目で返させる形（add_L 3.3）。分からない項目は省かせる（null は使わない） */
const RESULT_SCHEMA = {
  type: "object",
  properties: {
    officialUrl: {type: "string", description: "公式サイトのトップの URL"},
    officialX: {type: "string", description: "公式 X のユーザー名（@ なし）"},
    officialYoutube: {
      type: "string",
      description: "公式 YouTube チャンネルの URL（https://www.youtube.com/@... か " +
        "https://www.youtube.com/channel/UC...）。調査メモに書いてあるものだけ",
    },
    schedulePageUrl: {type: "string", description: "ライブ情報を読んだページの URL"},
    lives: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: {type: "string", description: "ライブ名（ツアー名・イベント名）"},
          officialUrl: {type: "string", description: "そのライブの公式ページの URL"},
          performances: {
            type: "array",
            items: {
              type: "object",
              properties: {
                date: {type: "string", description: "公演の日。YYYY-MM-DD"},
                startTime: {type: "string", description: "開演。HH:mm"},
                openTime: {type: "string", description: "開場。HH:mm"},
                venue: {type: "string", description: "会場名"},
                prefecture: {type: "string", description: "都道府県（例：東京都）"},
                online: {type: "boolean", description: "オンライン配信の公演か"},
              },
              required: ["date", "venue", "online"],
            },
          },
          receptions: {
            type: "array",
            items: {
              type: "object",
              properties: {
                type: {type: "string", enum: ["fc", "general", "upgrade", "other"]},
                name: {type: "string", description: "受付の名前（例：FC1次先行）"},
                applyStartAt: dateTime("申込（受付）の開始日時。受付期間「A〜B」の A"),
                applyEndAt: dateTime("申込（受付）の締切日時。受付期間「A〜B」の B。入金期限ではない"),
                resultAt: dateTime("当落（抽選結果）の発表日時"),
                paymentDeadline: dateTime("当選した後の入金（支払い）の期限。申込の締切ではない"),
                prices: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      seat: {type: "string", description: "席種"},
                      amount: {type: "integer", description: "料金（円・税込）"},
                    },
                    required: ["seat", "amount"],
                  },
                },
                winnersOnly: {type: "boolean", description: "当選した人だけが対象の受付か"},
              },
              required: ["type", "name", "winnersOnly"],
            },
          },
        },
        required: ["title", "performances", "receptions"],
      },
    },
  },
  required: ["lives"],
};

/** 1段目のプロンプト（add_L 3.5）。[pageUrls] は Functions がたどって集めたページ（L-4b） */
function researchPrompt(target, today, pageUrls, pageTexts = []) {
  const who = target.kind === "group" ? "グループ" : "人";
  const lines = [
    `今日は ${today}（日本時間）です。`,
    `次の${who}の、今日以降のライブ・コンサート・ツアー・イベントの情報を調べてください。`,
    `- 名前：${target.name}`,
  ];
  if (target.aliases.length > 0) lines.push(`- 別名：${target.aliases.join("、")}`);
  if (target.genre) lines.push(`- ジャンル：${GENRE_LABEL[target.genre] ?? target.genre}`);
  if (target.officialUrl) {
    lines.push(`- 公式サイト：${target.officialUrl}（運営が確認した公式サイト）`);
  }
  if (pageTexts.length > 0) {
    // Functions が取得したページの本文をそのまま渡す（URL コンテキストの読み込みに頼らない）
    lines.push(
        "",
        "公式サイトの、ライブ・イベントの一覧と詳細のページの本文です（取得済み）。これを読んで書き出してください：",
    );
    for (const p of pageTexts) lines.push("", `=== ${p.url} ===`, p.text);
  } else if (pageUrls.length > 0) {
    lines.push(
        "",
        "公式サイトの、ライブ・イベントの一覧と詳細のページです。まずこれらをすべて読んでください：",
        ...pageUrls.map((u) => `- ${u}`),
    );
  }
  lines.push(
      "",
      "手順：",
      target.officialUrl ?
        "1. 上の公式サイトは運営が確認済み。Google 検索で探し直さず、このサイト（と上に並べたページ）だけを使う。" +
          "ページの注意書き（架空・デモなど）があっても、公式サイトとして、書いてあるライブ・イベントを書き出す。" :
        "1. 公式サイトが分からなければ、Google 検索で公式サイトを探す。ファンサイト・まとめサイト・ニュースサイト・チケット転売サイトは公式サイトではない。",
      "2. 上のページ（無ければ公式サイトのライブ・ツアー・イベント・スケジュールのページ）を読む。開場・開演の時刻は、各公演の詳細ページに書いてあることが多い。",
      "3. 今日以降に開催される公演と、チケットの受付（ファンクラブ先行・プレイガイド先行・一般発売・アップグレードなど）を書き出す。テレビ・ラジオ・雑誌・配信番組への出演は書かない。",
      "",
      "決まり：",
      "- 公式サイトと、公式サイトからリンクされた公式のチケットページに書いてあることだけを書く。推測しない。分からないことは「不明」と書く。",
      "- 同じ名前の別の人・グループと取り違えない。",
      "- 日付は年まで書く。ページに年が無ければ、今日以降で最も近い日付になる年にする。時刻は日本時間。",
      "- ツアーは1つのライブにまとめ、会場・日ごとの公演を並べる。",
      "- 公式サイトの文章をそのまま長く写さず、項目だけを書く。",
      "- 書き出す項目：公式サイトのトップの URL、公式 X のユーザー名、" +
        "公式 YouTube チャンネルの URL、ライブ情報を読んだページ（一覧）の URL。" +
        "ライブごとに、ライブ名、ライブの公式ページの URL、公演（日付・開場・開演・会場・都道府県・オンライン配信か）、" +
        "受付（種類・名前・申込開始・申込締切・当落発表・入金期限・席種と料金・当選した人だけが対象か）。",
      "- 公式サイトが見つからなければ「公式サイトは見つからなかった」と書く。",
  );
  return lines.join("\n");
}

/** 2段目のプロンプト（add_L 3.5） */
function structurePrompt(memo, today) {
  return [
    "次の調査メモを、指定の JSON の形にしてください。",
    "- メモに書いていない項目・「不明」の項目は省く（推測で埋めない）。",
    "- 日時は日本時間で、YYYY-MM-DD または YYYY-MM-DDTHH:mm（時刻はHH:mm）。",
    "- 受付の種類：ファンクラブ先行は fc、一般発売は general、当選者向けの席のアップグレードは upgrade、それ以外（プレイガイド先行など）は other。",
    "- 受付の日時：申込締切（受付期間の終わり）は applyEndAt、入金期限は paymentDeadline。取り違えない。",
    "- 公式サイトが見つからなかったときは lives を空にする。",
    "",
    `今日：${today}`,
    "",
    "調査メモ：",
    memo,
  ].join("\n");
}

/**
 * 1段目：調べて文章で書き出す。
 * [pageTexts]（Functions が取得したページの本文）があれば、ツールを使わずにそれだけを読ませる。
 * 無ければ、公式サイトが分かっていれば URL コンテキストだけ、分からなければ Google 検索も使う。
 * 返り値：{memo, searchQueries}（searchQueries は Google 検索の語。最大5件）
 */
async function research(target, today, pageUrls = [], pageTexts = []) {
  const config = {};
  if (pageTexts.length === 0) {
    config.tools = target.officialUrl ?
      [{urlContext: {}}] :
      [{googleSearch: {}}, {urlContext: {}}];
  }
  const res = await ai().models.generateContent({
    model: GEMINI_MODEL,
    contents: researchPrompt(target, today, pageUrls, pageTexts),
    config,
  });
  const memo = (res.text ?? "").trim();
  if (!memo) throw new Error("Gemini の調査の結果が空でした");
  const queries = res.candidates?.[0]?.groundingMetadata?.webSearchQueries;
  const searchQueries = Array.isArray(queries) ?
    queries.filter((q) => typeof q === "string" && q.trim()).slice(0, 5) :
    [];
  return {memo, searchQueries};
}

/** 2段目：調査メモを JSON（add_L 3.3）にする */
async function structure(memo, today) {
  const res = await ai().models.generateContent({
    model: GEMINI_MODEL,
    contents: structurePrompt(memo, today),
    config: {
      responseMimeType: "application/json",
      responseJsonSchema: RESULT_SCHEMA,
      thinkingConfig: {thinkingLevel: "LOW"},
    },
  });
  try {
    return JSON.parse(res.text ?? "");
  } catch (e) {
    throw new Error("Gemini の結果を JSON として読めませんでした");
  }
}

module.exports = {GEMINI_MODEL, research, structure};