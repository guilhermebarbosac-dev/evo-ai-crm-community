# Changelog

All notable changes to **evo-ai-crm-community** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- N/A

### Changed

- N/A

### Fixed

- N/A

## [v1.0.0-rc3] - 2026-05-17

Release de estabilização — concentra correções de bugs em paridade de payload com Evolution Go (botões/listas), entrega de mídia outbound, hardening do endpoint Notificame verify, filtragem de secrets em logs Rails, bulk actions, escopo IDOR e diversas correções de automation rules. Também consolida a fundação do open-core via `EXTENSION_POINTS.md` + `lib/evo_extension_points/` (módulos no-op), introduz catálogo de products com variantes + venda em pipeline, export/import de bundles de templates (EVO-1116) e endpoint para limpar configurações de admin por tipo.

### Added

- **Catálogo de Products** — modelo completo de products com variantes, attach a agentes via tab dedicada e venda integrada ao pipeline (panel de vendas no item de pipeline).
- **Template Bundles — export & import (EVO-1116)** — exportação e importação de configuração via bundle ZIP. Permite empacotar inboxes, agentes, automation rules, canned responses e templates em um único arquivo portável entre instalações.
- **EVO-1051 — `DELETE` endpoint para limpar admin config por tipo** — operador da instalação pode resetar configurações específicas (SMTP, Storage, etc.) sem ter de editar o banco.
- **EVO-1287 — CI guard-rail para o contrato `EvoExtensionPoints`** (#76) — workflow que falha o PR se módulos do `lib/evo_extension_points/` forem modificados sem revisão consciente. Garante que a Enterprise edition continue podendo injetar implementações sem precisar de fork.
- **EVO-1286 — `lib/evo_extension_points/` com 5 módulos no-op** (#75) — pontos de extensão declarados como módulos no-op, prontos para serem reabertos pela Enterprise. Contrato versionado em `EXTENSION_POINTS.md`.
- **EVO-1283 — `EXTENSION_POINTS.md`** (#73) — documento declarando 4 hooks versionados expostos pelo CRM como contrato público de extensão.
- **EVO-1058** — operador `attribute_changed` em labels com dedup de dispatch (#56). Automation rules passam a reagir a mudanças de atribuição de label sem disparar duas vezes para o mesmo evento.
- **EVO-1057** — listeners para `conversation_resolved` e `conversation_status_changed` (#53). Amplia o vocabulário de triggers do automation rules para cobrir mudanças de status da conversa.
- **EVO-1011 — Bulk actions** — collect de resultados por item e resposta com `success_ids` / `failed_ids`, suporte a resolve em massa de conversas via checkbox.
- **Pipelines — `move_to_pipeline` action** — automation rules ganham ação para mover conversa entre pipelines preservando o id do item. Inclui dedup de `pipeline_stage_updated` em janela de 5s por `(rule, pipeline_item, stage)` para evitar tempestade de eventos.
- **Inboxes — expansão de variáveis em message templates** — variáveis ganham campos adicionais (`label`, `source`, `example`, `position`, `component`) acessíveis no template.
- **Automation rule runs — gerenciamento + cleanup job** — endpoint de API para consultar histórico de execução de regras + job de limpeza periódica.
- **Action service** — novos métodos `send_canned_response` e `send_template` no `ActionService` (uso direto pelas automations).
- **Spec de regressão** — `pipeline_item_spec` para fluxo de auto-assign-and-move (EVO-1080) (#57).
- **Spec de regressão** — Notificame verify endpoint (EVO-986).
- **Spec de regressão** — exclusão de contato com attachments (EVO-973) (#46).
- **Spec de contrato** — `Webhooks::Trigger` e endurecimento do spec de macros (EVO-1041).

### Changed

- **EVO-1113 — Consolidação de resolução de credenciais no `EvolutionConcern`** — antes a lógica estava espalhada por providers; agora um único concern centraliza o fallback per-field para `api_url`, `admin_token` e demais credenciais Evolution. Reduz superfície de bug e facilita troca entre Evolution API e Evolution Go.
- **Docs** padronizados para Evolution Foundation 2026 (README, LICENSE, NOTICE, TRADEMARKS).
- **Docs (org)** — URLs do GitHub atualizadas de `EvolutionAPI` para `evolution-foundation`.
- **Schema** — comments atualizados em `automation_rule_run`, `role` e `user_role`.
- **Schema** — removidas tabelas e foreign keys não utilizadas.

### Fixed

#### Mensageria — Evolution Go / Evolution API
- **EVO-1115 — payload de buttons/lists para Evolution Go** (#72) — formato corrigido para paridade com Evolution Go. Mensagens interativas (botões e listas) chegavam malformadas; agora seguem o schema esperado por ambos os providers.
- **EVO-1151 — falha de entrega de mídia outbound** (#70) — corrigido para Evolution API e Evolution Go. Anexos de outgoing não chegavam ao destinatário em determinados cenários de tamanho/codec.
- **Mensagens duplicadas no incoming handler do Evolution Go** — handler agora deduplica eventos antes de criar a conversa.
- **Fallback de configuração Evolution** — `api_url` e `admin_token` agora caem para o `GlobalConfig` quando a configuração por inbox está vazia.

#### Notificame / Webhooks
- **EVO-986 — Notificame verify endpoint hardening** — auth obrigatório, validação de payload, sem error leakage. Endpoint anterior expunha detalhes de erro úteis para enumeração.
- **EVO-1041 — Macro webhook delivery failures** — falhas em webhooks de macro agora são surfaceadas (antes ficavam silenciosas). Restrito o re-raise a `:macro_webhook` para evitar retry storm em outros tipos. Wired correto através de `ExecutionService` → `WebhookJob`.

#### Automation rules
- **EVO-1130 — Notificame attachment fallback_title** (#69) — prefere `content[:fileName]` quando disponível para gerar o título do anexo.
- **EVO-1049 — BMS/Resend delivery method** (#66) — corrigida resolução do símbolo do delivery method para a classe correta.
- **EVO-1011 — Bulk actions** — fix das findings HIGH de review (round 2 e 3), spec de fixture com `pipeline_type` válido (EVO-1047).
- **`labels` condition** — agora usa `EXISTS` subquery (independente e NULL-safe), resolve UUIDs para títulos com fallback, e casa label em conversation OU contact.
- **`message_type` filter** — aceita valores numéricos, não só keys de enum.
- **`apply_label` action** — resolve UUIDs para titles antes de tagear.
- **`pipeline_stage_updated`** — dedup em janela de 5s por `(rule, pipeline_item, stage)` evita disparo em rajada.
- **Cross-pipeline stage movement** — bypass correto da validação `same-pipeline` quando a action é `move_to_pipeline`.
- **Action templates** — `send_template` usa `deep_stringify_keys`, parâmetros melhorados.
- **`MessageTemplateVariable`** — definido localmente para evitar quebra de build.
- **Diagnostic logging** — adicionado em `move_to_pipeline` e `pipeline_stage_updated` para investigação de issues em produção.

#### Contacts / Pipeline
- **EVO-1018 — Group contacts** — distingue contatos de grupo WhatsApp de contatos reais de cliente; review feedback aplicado.

#### Mídia (EVO-999)
- **HIGH review findings** aplicadas para os fixes de mídia: fallback de `video file_type`, `fallback_title` em attachments, todos os caminhos de download cobertos.

#### Estabilidade
- **Docker — bundler version** — fixada durante installation para evitar build não-determinístico.
- **EVO-1047** — `pipeline_item_spec` usa `pipeline_type` válido na fixture (antes quebrava o spec).

### Security

- **EVO-1111 — Filtragem de secrets nos logs Rails** — campos sensíveis (`password`, `token`, `api_key`, etc.) passam pelo filter parameters do Rails antes de chegar ao log. Antes era possível vazar credenciais em logs de erro/debug.
- **EVO-1084 — IDOR scope no `BulkActionsJob`** — escopo de account aplicado no job; antes era possível, com um ID válido de outra conta, manipular recursos cross-tenant.
- **EVO-986 — Notificame verify endpoint** — auth obrigatório + validação fechada + sem error leakage (ver Fixed).

## [v1.0.0-rc2] - 2026-05-05

Release de estabilização — concentra correções de `500 Internal Server Error` em endpoints REST, fixes do fluxo Evolution Go, automation rules por stage, navegação card → conversation, performance de pipeline, migrations idempotentes para deploys em schemas drifted, RBAC de `super_admin` reconhecido como administrator em todos os bypasses, e signed URLs S3 para buckets privados em ambos os providers WhatsApp.

### Added

- **EVO-989** — **Automation rules por stage**: nova feature que permite configurar regras `trigger → action` por estágio do pipeline. Triggers suportados: `label_added`, `conversation_status_changed`, `custom_attribute_updated`. Actions: `move_to_stage`, `assign_agent`, `apply_label`. Execução assíncrona via Sidekiq com loop prevention (`Current.executed_by = :stage_automation`). Inclui `Pipelines::StageAutomationService`, `PipelineStageAutomationListener` e validação whitelist de payload no controller. (#44)
- **EVO-1007 backend** — `PipelineItemSerializer` agora expõe `conversation.uuid` na payload do pipeline para que o frontend possa navegar do card direto para `/conversations/<uuid>`. Mudança escopada (não toca `ConversationSerializer` global) para evitar regressão no chat. (#43)
- **EVO-1006** — busca e filtros adicionados ao kanban de pipeline (parte backend já estava na rc1, finalizada com `include_labels` na cadeia de serialização — #39).
- **EVO-987** — criação inline de label a partir do modal "Assign Label" (suporte backend).

### Fixed

#### API REST — bugs que causavam 500
- **`PATCH /api/v1/pipelines/:id/pipeline_items/:id/update_custom_fields`**: `before_action :set_pipeline_item` não cobria `:update_custom_fields`, então `@pipeline_item` ficava `nil` e cada chamada levantava `NoMethodError`. (#32)
- **`POST /api/v1/contacts/:id/companies` levantava `NoMethodError`**: `validate :must_belong_to_same_account` declarado em `ContactCompany` não tinha implementação. Definido como `no-op` (Community é single-tenant). (#34)
- **`POST` / `DELETE /api/v1/contacts/:id/companies` retornavam 500 em violação de regra de negócio**: `error_response(code:, message:)` com kwargs incompatíveis com a assinatura do helper (positional). Corrigido para retornar 400 com envelope `BUSINESS_RULE_VIOLATION`. (#35)
- **`/api/v1/agents/*` retornavam 500 / `Unauthorized`**: `current_user` era passado como primeiro argumento posicional para `EvoAiCoreService.*_agent` (a assinatura espera `params` / `agent_data` / `agent_id`); além disso, `request.headers` nunca era encaminhado, então o `evo-core` recebia chamadas sem token Bearer. (#33) — *follow-up registrado em [#42](https://github.com/EvolutionAPI/evo-ai-crm-community/issues/42) para replicar o fix nos demais controllers (`apikeys`, `folders`, etc).*
- **`GET /api/v1/oauth/applications`**: retornava array JSON puro, mas o frontend espera o envelope padrão `{ success, data, meta: { pagination } }`. Tela `/settings/integrations/oauth-apps` quebrava com `TypeError: Cannot read properties of undefined (reading 'pagination')`. (#36)
- **EVO-1000** — `POST /api/v1/team_members` retornava 401 + body `{"error":"Invalid User IDs"}` para todo UUID válido (a validação fazia `params[:user_ids].map(&:to_i)`, mas o PK do `User` é UUID — todos viravam `0` e nunca casavam). Resgate ajustado para `RecordInvalid` / `InvalidForeignKey` com 422 limpo. (#24)

#### Evolution Go (EvoGo) — fluxo WhatsApp
- **Conversation routing — sem mais conversas duplicadas**: quando o CRM enviava mensagem via EvoGo, o echo voltava como webhook com `IsFromMe: true`, mas a busca de contato era por phone number — outgoing usa identificador LID (`@lid`), então nenhum match era encontrado e uma conversa nova era criada a cada envio. Lookup agora prioriza identifier LID e usa fallback para phone. (#22)
- **Sender type correto e contact lookup**: outgoing eram salvos como `sender_type: Contact` em vez de `User`. Join de inbox no contact lookup também estava errado. Corrigido + reabertura de conversas pendentes ao chegar nova mensagem. (#22)
- **Mídia (imagem / áudio / vídeo) salva sem arquivo**: 3 problemas distintos resolvidos juntos: (1) `ActiveStorage#after_commit` não disparava em Sidekiq → migrado para `ActiveStorage::Blob.create_and_upload!` síncrono; (2) `mediaUrl` aninhado em `imageMessage`/`audioMessage`/etc. agora é extraído via `extract_media_url`; (3) EvoGo sem S3 manda mídia em `base64` inline — adicionado decode para `Tempfile`. (#22)
- **Áudio sem waveform / duração / PTT**: `configure_audio_metadata` e `audio_voice_note?` estavam **definidos duas vezes** no mesmo módulo (Ruby usava silenciosamente a última definição, que era stub incompleta com keys erradas). Mergidas em definições únicas usando symbol keys. Também removidos `save_message_and_notify` e `attach_media_from_url` que eram dead code. (#22)
- **ActionCable — broadcast em token vazio**: `account_token` retornava `""` (string vazia) quando account era nil, e `[account_token].compact` deixava passar a string vazia, causando broadcast em canal vazio. Função agora retorna `nil` (verdadeiro nil) e aceita Hash + AR-object como input. `ActionCableBroadcastJob` também passou a tolerar payload com keys string ou symbol. (#22)
- **Mídia em bucket S3 privado retornava 404 no chat**: `generate_direct_s3_url` montava a URL pública diretamente (`bucket.host/key`), mas instalações que usam Cloudflare R2 ou S3 com ACL privada bloqueiam acesso público. Substituído por `presigned_url` (signed URL com expiração curta) tanto no `whatsapp/providers/evolution_go_service.rb` (commit `316849d`) quanto no `whatsapp/providers/evolution_service.rb` (commit `daa9ee9` — o caminho do Evolution API tradicional foi corrigido em seguida com a mesma lógica).

#### Listeners e dispatchers
- **`ContactCompanyListener`**: eventos eram publicados via `Wisper::Publisher` com `data: { ... }`, mas todos os listeners do projeto leem como `event.data[:contact]` (esperando o wrapper `Events::Base` do `SyncDispatcher`). Resultado: `undefined method 'data' for an instance of Hash` no log + broadcast `CONTACT_COMPANY_LINKED` nunca disparava. Migrado para `Rails.configuration.dispatcher.dispatch(...)` em `LinkCompanyService`, `UnlinkCompanyService`, `Contact#add_company` e `#remove_company`; listener tolera `account: nil` via `single_tenant_account`. (#37)
- **EVO-975** — `assign_to_default_pipeline` na criação de conversa: removido `:account` do eager loading do `pipelines_controller#fetch_pipeline` (a associação não existe na edição community e gerava `AssociationNotFoundError`, impedindo `is_default: true` de ser persistido), e adicionado logging detalhado para diagnosticar futuros problemas. (#26)

#### Performance e listas
- **Pipeline chip na listagem de conversas só aparecia depois de tagear**: `ConversationFinder#build_conversations_query` mantinha o preload minimalista intencionalmente, sem `pipeline_items`. Como o `ConversationSerializer` só popula o bloco `pipelines` quando a associação está loaded, o frontend recebia `pipelines: []` e o `ConversationBadges` caía no branch "sem pipeline". Adicionado `pipeline_items: [:pipeline, :pipeline_stage]` ao preload — chip agora renderiza desde o primeiro load.

#### Serializers
- **EVO-1010** — `TeamSerializer` agora inclui `members_count` (rodando `team.team_members.count` indexado por `team_id`), corrigindo cards / linhas que mostravam `0 members` mesmo com membros associados. (#25)

#### RBAC — `super_admin` reconhecido como administrator
Quando o `evo-auth-service-community` introduziu o role `super_admin` (ver changelog de auth nesta mesma release), as listas hardcoded do CRM continuavam apontando só para `account_owner`, então o operador da instalação aparecia sem privilégios em vários bypasses sutis (mailers de admin, finders de admin, helpers de permissão).
- **`User#administrator?`**: passou a aceitar tanto `account_owner` quanto `super_admin` (`app/models/concerns/user_attribute_helpers.rb`). Antes filtros como `Conversation.assignable_by` retornavam vazio para super_admin, e a lista de conversas aparecia sem nada apesar do JWT estar válido.
- **`Role::ADMIN_ROLE_KEYS`**: nova constante centralizando `%w[account_owner super_admin]`. Adotada por `AdministratorNotifications::BaseMailer#admin_emails` (notificações de instalação) e por todo finder/scope que filtrava por role administrativo.
- **Effect**: nenhum endpoint precisou ser alterado individualmente — a constante consolidou o que estava espalhado em quatro lugares (commit `5f1eed2`).

#### Pipelines / Templates / Mensageria (do ciclo `develop`)
- **EVO-974**: aceita payload com filtros aninhados, suporta `pipeline_id` / `contact_id`, e `query_builder` agora pareia `row + clause` para sobreviver a cláusulas vazias.
- **EVO-1002**: `MessageTemplate#serialized` espelha `settings.status` no top-level; criação de template roteia pelo provider sync (Meta) e não inverte mais `active` para `false` em sync de templates `PENDING` / `REJECTED`.
- **EVO-1001**: resolve UUIDs de labels ao tagear / renderizar conversas. (#14)
- **EVO-1005**: `pipeline_items#update` persiste `pipeline_stage_id`. (#27)
- **EVO-1006**: `include_labels` agora atravessa toda a cadeia de serialização do pipeline. (#39)
- **EVO-984**: fallback de credencial + webhook eager para Evolution Go. (#41)
- **EVO-1055**: novo endpoint `GET /api/v1/evolution/health` que faz proxy para `${api_url}/` do Evolution API e retorna o JSON upstream. O frontend `EvolutionService.healthCheck` dependia dessa rota para validar a URL configurada antes de criar um canal WhatsApp; sem ela, toda criação de canal Evolution API caía em 404 com "Health check falhou" e nenhum caminho adiante. Controller espelha o padrão `Net::HTTP` de `authorizations_controller#check_server_status` (timeout 5s open/read). (#45)
- **EVO-985**: `BACKEND_URL` apontando para `localhost` é bloqueado em produção. (#30)
- **EVO-996**: preserva `in_reply_to` quando a mensagem-pai ainda não foi resolvida. (#31)
- **EVO-1012**: expõe `thumbnail` e fia o avatar fetch via Evolution API. (#28)
- **WhatsApp groups**: mensagens de grupo agora são ingeridas em uma única conversa por grupo (não mais uma por participante). (#29)

#### Migrations idempotentes (PR #21)
Quatro migrations tornadas seguras para re-run em PROD com schema drifted (ou parcialmente migrado por crash anterior). Sem isso, deploys em ambientes existentes podiam quebrar com `PG::DuplicateTable` / `PG::UndefinedColumn`. Sourcery review aplicado com guards individuais para cada `add_index` / backfill (sem early return cego).
- `20251119155458_make_attachment_polymorphic.rb` — guards de `column_exists?` no add_index polimórfico.
- `20251117132621_add_type_to_contacts.rb` — `add_index` e backfill de `Contact.where(type: nil)` separados do guard de coluna; também passa a criar o índice composto `idx_contacts_name_type_resolved` se a coluna `type` já existir (cooperação com a migration `20241020`).
- `20260414120000_create_user_tours.rb` — `unless table_exists?` no `create_table` + `unless index_exists?` em cada `add_index`, em vez do early return que pulava índices.
- `20251114150000_add_sentiment_analysis_fields_to_facebook_comment_moderations.rb` — `if_not_exists: true` em todas as colunas adicionadas.

#### Migration ordering — `OptimizeContactsPerformance`
- Migration `20241020000100_optimize_contacts_performance.rb` (vinda do PR #40) tinha timestamp de outubro/2024 — fresh installs rodavam ela antes de `AddTypeToContacts` (`20251117`), tentando criar índice em `contacts(name, type, id)` quando a coluna `type` ainda não existia → `PG::UndefinedColumn`. Solução: `IF NOT EXISTS` em todos os `CREATE INDEX` e guard `column_exists?(:contacts, :type)` para o índice composto. `AddTypeToContacts` faz backfill desse índice depois de adicionar a coluna. Sem mudança de timestamp (PROD existente intacto).

#### Import de contatos / Roles (PR #40)
- **Sanitização de CPF/CNPJ na importação** via novo método `sanitize_tax_id` em `ContactManager`. CPF/CNPJ formatados são salvos apenas com números.
- **Otimização de performance**: `Contact.resolved_contacts` migrada para `LEFT JOIN`, cache de count no controller (1 minuto), novos índices em `contact_inboxes` e `contacts`.
- **Models `Role` e `UserRole`** introduzidos no CRM para consumir roles sincronizadas do `evo-auth-service` (suporte a notificações de admin role-based).
- **`format_phone_number`** preservou prefixo `+`.
- **CSV de import** com formato expandido (person/company, tax_id, social profiles, custom_attributes).

#### Banco / DevOps
- **db**: dropados FKs para tabela `users` removida (que travavam `db:migrate`). (#3)
- **evolution_go**: `api_url` e `admin_token` agora persistem no `provider_config` a partir do `GlobalConfig`. (#5)
- **whatsapp_cloud**: removido fetch de avatar do Evolution Go no fluxo Cloud inbound.

### Changed

- **CI**: workflow agora também publica imagens `develop` para staging.

## [v1.0.0-rc1] - 2026-04-24

### Added

- Primeiro release candidate público do `evo-ai-crm-community`.
- API REST `Api::V1::*` com controladores para conversas, contatos, pipelines, agents, OAuth applications, teams, channels, etc.
- Integração com `evo-ai-core-service` (agents) via `EvoAiCoreService`.
- Listeners de eventos via `Wisper` + `SyncDispatcher` com broadcasts para `ActionCableListener`.
- Serializers `MessageTemplate`, `Team`, `Pipeline`, etc.
- Background jobs (`Webhooks::WhatsappEventsJob`, `ActionCableBroadcastJob`).
- Master schema do banco como fonte de verdade do setup.

---

[Unreleased]: https://github.com/evolution-foundation/evo-ai-crm-community/compare/v1.0.0-rc3...HEAD
[v1.0.0-rc3]: https://github.com/evolution-foundation/evo-ai-crm-community/compare/v1.0.0-rc2...v1.0.0-rc3
[v1.0.0-rc2]: https://github.com/evolution-foundation/evo-ai-crm-community/compare/v1.0.0-rc1...v1.0.0-rc2
[v1.0.0-rc1]: https://github.com/EvolutionAPI/evo-ai-crm-community/releases/tag/v1.0.0-rc1
