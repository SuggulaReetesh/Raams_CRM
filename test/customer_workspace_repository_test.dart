import 'package:flutter_test/flutter_test.dart';
import 'package:raams_crm/customer.dart';
import 'package:raams_crm/delivery.dart';
import 'package:raams_crm/finance.dart';
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

  test(
    'line-item catalog stores workspace tier rates and starter items',
    () async {
      SharedPreferences.setMockInitialValues({});
      const repository = SharedPreferencesCustomerWorkspaceRepository();

      final initialCatalog = await repository.loadLineItemCatalog();
      expect(initialCatalog, hasLength(6));
      expect(initialCatalog.first.basicRatePerSqft, isNull);

      await repository.saveLineItemCatalogEntry(
        const StudioLineItemCatalogEntry(
          id: 'starter-wardrobe',
          name: 'Wardrobe',
          basicRatePerSqft: 100,
          mediumRatePerSqft: 150,
          luxuryRatePerSqft: 200,
          version: 2,
        ),
      );

      final restored = await repository.loadLineItemCatalog();
      expect(restored.first.rateForQuality('Basic'), 100);
      expect(restored.first.rateForQuality('Medium'), 150);
      expect(restored.first.rateForQuality('Luxury'), 200);
    },
  );

  test('workspace codec round-trips milestone two planning records', () async {
    SharedPreferences.setMockInitialValues({});
    const repository = SharedPreferencesCustomerWorkspaceRepository();
    final workspace = await repository.loadWorkspace(
      initialCustomers: const [],
      initialStages: const ['New inquiry', 'Discovery'],
    );
    final project = StudioProject(
      id: 'project-1',
      name: 'North site',
      location: 'North site address',
      status: 'Planning',
      customerId: null,
      targetDate: DateTime(2027, 12, 31),
      startDate: DateTime(2027, 1, 1),
      budget: 250000,
    );
    final phase = StudioProjectPhase(
      id: 'phase-1',
      projectId: project.id,
      name: 'Foundation',
      position: 0,
      status: 'Not started',
      startDate: DateTime(2027, 1, 1),
      endDate: DateTime(2027, 2, 1),
    );
    final delivery = workspace.delivery.copyWith(
      projects: [project],
      phases: [phase],
      tasks: [
        StudioTaskRecord(
          id: 'task-1',
          projectId: project.id,
          title: 'Pour foundation',
          assignee: '',
          dueDate: DateTime(2027, 1, 15),
          isComplete: false,
          priority: 'High',
        ),
        StudioTaskRecord(
          id: 'task-2',
          projectId: project.id,
          title: 'Inspect foundation',
          assignee: 'Owner',
          dueDate: DateTime(2027, 1, 20),
          isComplete: false,
          priority: 'Normal',
          dependsOnTaskIds: const ['task-1'],
        ),
      ],
      milestones: [
        StudioMilestone(
          id: 'milestone-1',
          projectId: project.id,
          title: 'Foundation complete',
          dueDate: DateTime(2027, 2, 1),
          status: 'Not started',
          update: '',
          updatedAt: DateTime(2027, 1, 1),
          phaseId: phase.id,
        ),
      ],
      materials: const [
        StudioMaterial(
          id: 'material-1',
          name: 'Concrete',
          category: 'Cement & concrete',
          unit: 'm3',
          specification: 'M25',
          description: '',
          isActive: true,
        ),
      ],
      vendors: const [
        StudioVendor(
          id: 'vendor-1',
          name: 'North Supply',
          kind: 'Supplier',
          email: 'orders@example.test',
          phone: '',
          address: '',
          taxId: '',
          paymentTerms: 'Net 30',
          notes: '',
          isActive: true,
          documents: [
            StudioVendorDocument(
              id: 'vendor-document-1',
              name: 'Trade licence',
              documentType: 'Licence',
              reference: 'LIC-100',
              expiresAt: null,
            ),
          ],
        ),
      ],
    );
    final encoded = repository.encodeWorkspaceData(
      customers: workspace.customers,
      pipelineStages: workspace.pipelineStages,
      activities: workspace.activities,
      personas: workspace.personas,
      preferences: workspace.preferences,
      delivery: delivery,
      financials: workspace.financials,
      communications: workspace.communications,
    );

    final restored = repository.decodeWorkspaceData(
      encoded,
      initialCustomers: const [],
      initialStages: const ['New inquiry', 'Discovery'],
    );

    expect(restored.delivery.projects.single.budget, 250000);
    expect(restored.delivery.phases.single.name, 'Foundation');
    expect(restored.delivery.tasks.last.dependsOnTaskIds, ['task-1']);
    expect(restored.delivery.milestones.single.phaseId, phase.id);
    expect(restored.delivery.materials.single.unit, 'm3');
    expect(
      restored.delivery.vendors.single.documents.single.reference,
      'LIC-100',
    );
  });

  test(
    'schema four workspaces migrate without losing prior project data',
    () async {
      SharedPreferences.setMockInitialValues({});
      const repository = SharedPreferencesCustomerWorkspaceRepository();
      final workspace = await repository.loadWorkspace(
        initialCustomers: const [],
        initialStages: const ['New inquiry', 'Discovery'],
      );
      final oldProject = StudioProject(
        id: 'old-project',
        name: 'Existing project',
        location: 'Existing site',
        status: 'In progress',
        customerId: null,
        targetDate: null,
      );
      final encoded = repository.encodeWorkspaceData(
        customers: workspace.customers,
        pipelineStages: workspace.pipelineStages,
        activities: workspace.activities,
        personas: workspace.personas
            .map(
              (persona) => persona.copyWith(
                permissions: persona.permissions
                    .where(
                      (permission) => !{
                        StudioPersona.viewMaterials,
                        StudioPersona.manageMaterials,
                        StudioPersona.viewVendors,
                        StudioPersona.manageVendors,
                      }.contains(permission),
                    )
                    .toList(),
              ),
            )
            .toList(),
        preferences: workspace.preferences,
        delivery: workspace.delivery.copyWith(projects: [oldProject]),
        financials: workspace.financials,
        communications: workspace.communications,
      );
      encoded['schemaVersion'] = 4;
      final delivery = Map<String, Object?>.from(encoded['delivery']! as Map);
      delivery.remove('phases');
      delivery.remove('materials');
      delivery.remove('vendors');
      encoded['delivery'] = delivery;

      final restored = repository.decodeWorkspaceData(
        encoded,
        initialCustomers: const [],
        initialStages: const ['New inquiry', 'Discovery'],
      );

      expect(restored.delivery.phases, isEmpty);
      expect(restored.delivery.materials, isEmpty);
      expect(restored.delivery.vendors, isEmpty);
      expect(restored.delivery.projects.single.name, 'Existing project');
      expect(
        restored.personas.first.permissions,
        contains(StudioPersona.manageMaterials),
      );
      expect(encoded['schemaVersion'], 4);
    },
  );
}
