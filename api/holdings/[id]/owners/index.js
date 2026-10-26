import dispatch from "./../../../../server/router.js";

export default (req, res) => dispatch(req, res, `holdings/${req.query.id}/owners`);
