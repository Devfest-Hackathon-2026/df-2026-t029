/**
 * 都道府県の代表地点（都道府県庁の所在地）。天気の位置に使う（add_E 5.1）
 * code は JIS の都道府県コード（キャッシュのドキュメント ID に使う）
 */
const PREFECTURES = [
  {code: 1, name: "北海道", lat: 43.0642, lng: 141.3469},
  {code: 2, name: "青森", lat: 40.8244, lng: 140.74},
  {code: 3, name: "岩手", lat: 39.7036, lng: 141.1527},
  {code: 4, name: "宮城", lat: 38.2688, lng: 140.8721},
  {code: 5, name: "秋田", lat: 39.7186, lng: 140.1024},
  {code: 6, name: "山形", lat: 38.2404, lng: 140.3633},
  {code: 7, name: "福島", lat: 37.7503, lng: 140.4676},
  {code: 8, name: "茨城", lat: 36.3418, lng: 140.4468},
  {code: 9, name: "栃木", lat: 36.5657, lng: 139.8836},
  {code: 10, name: "群馬", lat: 36.3911, lng: 139.0608},
  {code: 11, name: "埼玉", lat: 35.8569, lng: 139.6489},
  {code: 12, name: "千葉", lat: 35.6046, lng: 140.1233},
  {code: 13, name: "東京", lat: 35.6895, lng: 139.6917},
  {code: 14, name: "神奈川", lat: 35.4478, lng: 139.6425},
  {code: 15, name: "新潟", lat: 37.9024, lng: 139.0236},
  {code: 16, name: "富山", lat: 36.6953, lng: 137.2113},
  {code: 17, name: "石川", lat: 36.5947, lng: 136.6256},
  {code: 18, name: "福井", lat: 36.0652, lng: 136.2216},
  {code: 19, name: "山梨", lat: 35.6642, lng: 138.5684},
  {code: 20, name: "長野", lat: 36.6513, lng: 138.181},
  {code: 21, name: "岐阜", lat: 35.3912, lng: 136.7223},
  {code: 22, name: "静岡", lat: 34.9769, lng: 138.3831},
  {code: 23, name: "愛知", lat: 35.1802, lng: 136.9066},
  {code: 24, name: "三重", lat: 34.7303, lng: 136.5086},
  {code: 25, name: "滋賀", lat: 35.0045, lng: 135.8686},
  {code: 26, name: "京都", lat: 35.0214, lng: 135.7556},
  {code: 27, name: "大阪", lat: 34.6863, lng: 135.52},
  {code: 28, name: "兵庫", lat: 34.6913, lng: 135.183},
  {code: 29, name: "奈良", lat: 34.6851, lng: 135.8329},
  {code: 30, name: "和歌山", lat: 34.226, lng: 135.1675},
  {code: 31, name: "鳥取", lat: 35.5039, lng: 134.2377},
  {code: 32, name: "島根", lat: 35.4723, lng: 133.0505},
  {code: 33, name: "岡山", lat: 34.6618, lng: 133.9344},
  {code: 34, name: "広島", lat: 34.3966, lng: 132.4596},
  {code: 35, name: "山口", lat: 34.1859, lng: 131.4714},
  {code: 36, name: "徳島", lat: 34.0658, lng: 134.5593},
  {code: 37, name: "香川", lat: 34.3401, lng: 134.0434},
  {code: 38, name: "愛媛", lat: 33.8417, lng: 132.7661},
  {code: 39, name: "高知", lat: 33.5597, lng: 133.5311},
  {code: 40, name: "福岡", lat: 33.6064, lng: 130.4183},
  {code: 41, name: "佐賀", lat: 33.2494, lng: 130.2988},
  {code: 42, name: "長崎", lat: 32.7448, lng: 129.8737},
  {code: 43, name: "熊本", lat: 32.7898, lng: 130.7417},
  {code: 44, name: "大分", lat: 33.2382, lng: 131.6126},
  {code: 45, name: "宮崎", lat: 31.9111, lng: 131.4239},
  {code: 46, name: "鹿児島", lat: 31.5602, lng: 130.5581},
  {code: 47, name: "沖縄", lat: 26.2124, lng: 127.6809},
];

/**
 * 都道府県の名前から代表地点を探す。「都・府・県」は外して照合する
 * （「東京都」でも「東京」でもよい。北海道は「北海道」のまま）。
 * 見つからなければ null
 */
function findPrefecture(name) {
  if (typeof name !== "string") return null;
  const key = name.trim().replace(/[都府県]$/, "");
  return PREFECTURES.find((p) => p.name === key) ?? null;
}

module.exports = {PREFECTURES, findPrefecture};