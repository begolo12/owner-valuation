import dispatch from "./../../../../server/router.js";

export default (req, res) => dispatch(req, res, `owners/${req.query.id}/assessments/${req.query.aid}`);
