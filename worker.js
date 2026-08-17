export default {
  async fetch(request) {
    return new Response("WORKER OK", {
      status: 200
    });
  }
};
