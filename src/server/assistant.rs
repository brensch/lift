use super::*;
use crate::db::Consent;
use crate::mcp::{check_connect, redirect_back, Mcp, CAN, SCOPE};

// ── Assistant Service ──
//
// The website's /connect page (the OAuth authorization endpoint for MCP)
// and the app's "Connected assistants": describe a connection request,
// answer it as the signed-in person, list and revoke what they allowed.
// The OAuth endpoints themselves are in src/mcp.

#[derive(Clone)]
pub struct ServerAssistantService {
    pub db: ServerDb,
    pub mcp: Mcp,
}

#[tonic::async_trait]
impl AssistantService for ServerAssistantService {
    async fn describe_connect(
        &self,
        request: Request<DescribeConnectRequest>,
    ) -> Result<Response<DescribeConnectResponse>, Status> {
        // Shown before signing in: nothing in it is the person's.
        let connect = request.into_inner().request.unwrap_or_default();
        let client = check_connect(&self.mcp, &connect)
            .await
            .map_err(Status::invalid_argument)?;
        let redirect_host = url::Url::parse(&connect.redirect_uri)
            .ok()
            .and_then(|u| {
                u.host_str()
                    .map(str::to_string)
                    .or(Some(u.scheme().to_string()))
            })
            .unwrap_or_default();
        Ok(Response::new(DescribeConnectResponse {
            client_name: client.client_name,
            redirect_host,
            can: CAN.iter().map(|c| c.to_string()).collect(),
        }))
    }

    async fn answer_connect(
        &self,
        request: Request<AnswerConnectRequest>,
    ) -> Result<Response<AnswerConnectResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let answer = request.into_inner();
        let connect = answer.request.unwrap_or_default();
        let client = check_connect(&self.mcp, &connect)
            .await
            .map_err(Status::invalid_argument)?;
        info!(rpc = "AnswerConnect", %user_id, client = %client.client_name, allow = answer.allow, "request");
        let redirect_to = if answer.allow {
            let code = self
                .db
                .issue_assistant_code(&Consent {
                    user_id,
                    client_id: client.client_id,
                    redirect_uri: connect.redirect_uri.clone(),
                    code_challenge: connect.code_challenge,
                    scope: SCOPE.to_string(),
                })
                .await
                .map_err(internal_error)?;
            redirect_back(
                &connect.redirect_uri,
                &[
                    ("code", code.as_str()),
                    ("state", connect.state.as_str()),
                    ("iss", self.mcp.origin.as_str()),
                ],
            )
        } else {
            redirect_back(
                &connect.redirect_uri,
                &[
                    ("error", "access_denied"),
                    ("state", connect.state.as_str()),
                ],
            )
        };
        Ok(Response::new(AnswerConnectResponse { redirect_to }))
    }

    async fn list_assistants(
        &self,
        request: Request<ListAssistantsRequest>,
    ) -> Result<Response<ListAssistantsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let grants = self
            .db
            .assistant_grants(&user_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(ListAssistantsResponse {
            grants: grants
                .into_iter()
                .map(|g| AssistantGrant {
                    grant_id: g.grant_id,
                    client_name: g.client_name,
                    created_at: g.created_at,
                    last_used_at: g.last_used_at,
                    scope: g.scope,
                })
                .collect(),
        }))
    }

    async fn revoke_assistant(
        &self,
        request: Request<RevokeAssistantRequest>,
    ) -> Result<Response<RevokeAssistantResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let grant_id = request.into_inner().grant_id;
        info!(rpc = "RevokeAssistant", %user_id, %grant_id, "request");
        if !self
            .db
            .revoke_assistant(&user_id, &grant_id)
            .await
            .map_err(internal_error)?
        {
            return Err(Status::not_found("No such assistant"));
        }
        Ok(Response::new(RevokeAssistantResponse {}))
    }
}
