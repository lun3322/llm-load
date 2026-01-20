<script setup lang="ts">
import { keysApi } from "@/api/keys";
import type { APIKey, Group } from "@/types/models";
import { ref, watch, computed, h } from "vue";
import { useI18n } from "vue-i18n";
import {
  NButton,
  NCard,
  NDataTable,
  NInput,
  NSpace,
  NSpin,
  NModal,
  NTag,
  useDialog,
  NEmpty,
  NDivider,
  type DataTableColumns,
} from "naive-ui";
import { CheckmarkCircle, AlertCircleOutline, WarningOutline, Search } from "@vicons/ionicons5";

const { t } = useI18n();
const dialog = useDialog();

interface Props {
  show: boolean;
  group: Group | null;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  "update:show": [value: boolean];
  refresh: [];
}>();

const keys = ref<APIKey[]>([]);
const loading = ref(false);
const searchText = ref("");
const responseFilter = ref("");

const columns = computed<DataTableColumns<APIKey>>(() => [
  {
    title: t("keys.id"),
    key: "id",
    width: 80,
  },
  {
    title: t("keys.keyValue"),
    key: "key_value",
    ellipsis: { tooltip: true },
  },
  {
    title: t("keys.status"),
    key: "status",
    width: 100,
    render(row) {
      const status = row.status || "unknown";
      const type = status === "active" ? "success" : status === "deprecated" ? "warning" : "error";
      const icon = status === "active" ? CheckmarkCircle : status === "deprecated" ? WarningOutline : AlertCircleOutline;
      return h(
        NTag,
        {
          type: type as any,
          bordered: false,
        },
        {
          icon: () => h(icon),
          default: () => t(`keys.status${status.charAt(0).toUpperCase() + status.slice(1)}`),
        }
      );
    },
  },
  {
    title: t("keys.lastValidationResponse"),
    key: "last_validation_response",
    ellipsis: { tooltip: true },
    render(row) {
      return row.last_validation_response || "-";
    },
  },
  {
    title: t("keys.actions"),
    key: "actions",
    width: 180,
    render(row) {
      return h(
        NSpace,
        { size: "small" },
        () => [
          h(
            NButton,
            {
              size: "small",
              type: "warning",
              onClick: () => batchUpdateToDeprecated(row.last_validation_response || ""),
              disabled: row.status === "deprecated",
            },
            () => t("keys.setToDeprecated")
          ),
        ]
      );
    },
  },
]);

watch(
  () => props.show,
  async newVal => {
    if (newVal) {
      await loadKeys();
    }
  }
);

async function loadKeys() {
  if (!props.group?.id) {
    return;
  }

  try {
    loading.value = true;
    const result = await keysApi.getGroupKeys({
      group_id: props.group.id,
      page: 1,
      page_size: 1000,
    });
    keys.value = result.items;
  } catch (error) {
    console.error("Failed to load keys:", error);
    window.$message?.error(t("keys.loadFailed"));
  } finally {
    loading.value = false;
  }
}

const filteredKeys = computed(() => {
  if (!responseFilter.value) {
    return keys.value;
  }
  const filter = responseFilter.value.toLowerCase();
  return keys.value.filter(key => key.last_validation_response?.toLowerCase().includes(filter));
});

function handleSearch() {
  responseFilter.value = responseFilter.value;
}

async function batchUpdateToDeprecated(response: string) {
  const groupId = props.group?.id;
  if (!groupId || !response) {
    return;
  }

  dialog.warning({
    title: t("keys.batchUpdateToDeprecated"),
    content: t("keys.confirmBatchUpdateToDeprecated", { response }),
    positiveText: t("common.confirm"),
    negativeText: t("common.cancel"),
    onPositiveClick: async () => {
      try {
        await keysApi.batchUpdateKeyStatus({
          group_id: groupId,
          last_validation_response: response,
          new_status: "deprecated",
        });
        window.$message.success(t("keys.batchUpdateSuccess"));
        await loadKeys();
        emit("refresh");
      } catch (error) {
        console.error("Batch update failed:", error);
        window.$message.error(t("keys.batchUpdateFailed"));
      }
    },
  });
}

function handleClose() {
  emit("update:show", false);
  searchText.value = "";
  responseFilter.value = "";
}
</script>

<template>
  <n-modal :show="show" :mask-closable="true" @update:show="handleClose">
    <n-card style="width: 900px; max-height: 80vh" :title="t('keys.manageKeys')" :bordered="false" size="huge" role="dialog" aria-modal="true">
      <div class="manage-dialog-content">
        <div class="filter-section">
          <n-space vertical>
            <n-input
              v-model:value="responseFilter"
              :placeholder="t('keys.filterByLastValidationResponse')"
              clearable
              @input="handleSearch"
            >
              <template #prefix>
                <n-icon :component="Search" />
              </template>
            </n-input>
          </n-space>
        </div>

        <n-divider />

        <div class="table-section">
          <n-spin :show="loading">
            <n-empty v-if="filteredKeys.length === 0 && !loading" :description="t('keys.noMatchingKeys')" />
            <n-data-table
              v-else
              :columns="columns"
              :data="filteredKeys"
              :pagination="{ pageSize: 10 }"
              :max-height="400"
              striped
            />
          </n-spin>
        </div>
      </div>

      <template #footer>
        <n-space justify="end">
          <n-button @click="handleClose">{{ t("common.close") }}</n-button>
        </n-space>
      </template>
    </n-card>
  </n-modal>
</template>

<style scoped>
.manage-dialog-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.filter-section {
  padding: 12px;
  background: var(--bg-secondary);
  border-radius: 8px;
}

.table-section {
  flex: 1;
  overflow: auto;
}
</style>