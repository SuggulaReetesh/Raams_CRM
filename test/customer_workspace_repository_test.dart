import 'package:flutter_test/flutter_test.dart';
import 'package:raams_crm/customer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'shared-preferences adapter satisfies the workspace repository contract',
    () async {
      SharedPreferences.setMockInitialValues({});
      const CustomerWorkspaceRepository repository =
          SharedPreferencesCustomerWorkspaceRepository();
      const stages = ['New inquiry', 'Discovery'];

      final initial = await repository.loadWorkspace(
        initialCustomers: const [],
        initialStages: stages,
      );
      await repository.saveWorkspace(
        customers: initial.customers,
        pipelineStages: initial.pipelineStages,
        activities: initial.activities,
        personas: initial.personas,
        preferences: initial.preferences,
        delivery: initial.delivery,
        financials: initial.financials,
        communications: initial.communications,
      );

      final restored = await repository.loadWorkspace(
        initialCustomers: const [],
        initialStages: stages,
      );

      expect(restored.pipelineStages, stages);
      expect(restored.personas, isNotEmpty);
      expect(restored.financials.templates, isNotEmpty);
    },
  );
}
