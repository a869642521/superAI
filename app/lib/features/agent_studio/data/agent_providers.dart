import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starpath/features/agent_studio/data/agent_repository.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';

final agentRepositoryProvider = Provider((ref) => AgentRepository());

final myAgentsProvider = FutureProvider.autoDispose<List<AgentModel>>((ref) {
  return ref.read(agentRepositoryProvider).getMyAgents();
});

final agentTemplatesProvider =
    FutureProvider.autoDispose<List<AgentTemplate>>((ref) {
  return ref.read(agentRepositoryProvider).getTemplates();
});
