const GITHUB_CONFIG =
  "https://raw.githubusercontent.com/fufan2k2/SyncScript/main/Update-FreeFileSyncExclude.ps1";

export default {
  async fetch(request) {

    // =========================
    // THỜI GIAN ĐƯỢC PHÉP
    // =========================

    const START_TIME = 8 * 60;  // 08:00
    const END_TIME   = 9 * 60;  // 09:00


    // =========================
    // GIỜ VIỆT NAM
    // =========================

    const now = new Date();

    const vietnamTime = new Date(
      now.toLocaleString("en-US", {
        timeZone: "Asia/Ho_Chi_Minh"
      })
    );

    const hour = vietnamTime.getHours();
    const minute = vietnamTime.getMinutes();

    const currentMinutes = hour * 60 + minute;


    // =========================
    // KIỂM TRA GIỜ
    // =========================

    if (
      currentMinutes < START_TIME ||
      currentMinutes >= END_TIME
    ) {

      return new Response(
        JSON.stringify({
          success: false,
          error: "ACCESS_DENIED",
          message: "Ngoài thời gian được phép tải file",
          time: `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`
        }),
        {
          status: 403,
          headers: {
            "Content-Type": "application/json",
            "Cache-Control": "no-store"
          }
        }
      );
    }


    // =========================
    // LẤY FILE TỪ GITHUB
    // =========================

    const response = await fetch(GITHUB_CONFIG);

    if (!response.ok) {

      return new Response(
        JSON.stringify({
          success: false,
          error: "GITHUB_ERROR",
          status: response.status
        }),
        {
          status: 502,
          headers: {
            "Content-Type": "application/json"
          }
        }
      );
    }


    // =========================
    // TRẢ FILE
    // =========================

    const content = await response.text();

    return new Response(content, {
      status: 200,
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-store"
      }
    });
  }
};
