<script setup lang="ts">
import { keysApi } from "@/api/keys";
import type { APIKey, Group } from "@/types/models";
import { ref, watch, computed, h } from "vue";
import { useI18n } from "vue-i18n";
import {
  NButton,
  NButtonGroup,
  NCard,
  NDataTable,
  NInput,
  NSpace,
  NSpin,
  NModal,
  NTag,
  useDialog,
  NEmpty,
  NSelect,
  NTooltip,
  type DataTableColumns,
} from "naive-ui";
import { WarningOutline, Search } from "@vicons/ionicons5";

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
const statusFilter = ref<"all" | "active" | "invalid" | "deprecated">("all");
const currentPage = ref(1);
const pageSize = ref(10);
const total = ref(0);
const totalPages = computed(() => Math.ceil(total.value / pageSize.value));

// 状态过滤选项
const statusOptions = [
  { label: t("keys.all"), value: "all" },
  { label: t("keys.valid"), value: "active" },
  { label: t("keys.invalid"), value: "invalid" },
  { label: t("keys.deprecated"), value: "deprecated" },
];

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
      const type = status === "active" ? "success" : status === "deprecated" ? "warning" : status === "invalid" ? "error" : "default";
      return h(
        NTag,
        { type: type as any, size: "small", round: true },
        { default: () => t(`keys.status${status.charAt(0).toUpperCase() + status.slice(1)}`) }
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
]);

watch(
  () => props.show,
  async newVal => {
    if (newVal) {
      statusFilter.value = "all";
      responseFilter.value = "";
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
    total.value = result.pagination.total_items;
  } catch (error) {
    console.error("Failed to load keys:", error);
    window.$message?.error(t("keys.loadFailed"));
  } finally {
    loading.value = false;
  }
}

const filteredKeys = computed(() => {
  let filtered = keys.value;

  // 状态筛选
  if (statusFilter.value !== "all") {
    filtered = filtered.filter(key => key.status === statusFilter.value);
  }

  // 验证响应筛选
  if (responseFilter.value) {
    const filter = responseFilter.value.toLowerCase();
    filtered = filtered.filter(key => key.last_validation_response?.toLowerCase().includes(filter));
  }

  return filtered;
});

// 监听筛选条件变化，重置页码
watch([statusFilter, responseFilter], () => {
  currentPage.value = 1;
});

const paginatedKeys = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value;
  const end = start + pageSize.value;
  return filteredKeys.value.slice(start, end);
});

function changePage(page: number) {
  currentPage.value = page;
}

function changePageSize(size: number) {
  pageSize.value = size;
  currentPage.value = 1;
}

function handleSearch() {
  // 筛选通过 computed 属性自动进行，这里不需要额外操作
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
  statusFilter.value = "all";
}
</script>

<template>
  <n-modal :show="show" :mask-closable="true" @update:show="handleClose">
    <n-card class="manage-card" :title="t('keys.manageKeys')" :bordered="false" size="huge" role="dialog" aria-modal="true">
      <div class="manage-dialog-content">
        <n-space vertical>
          <!-- 工具栏 -->
          <div class="toolbar">
            <div class="filter-section">
              <div class="filter-row">
                <div class="filter-grid">
                  <div class="filter-item">
                    <n-select
                      v-model:value="statusFilter"
                      :options="statusOptions"
                      size="small"
                      :placeholder="t('keys.allStatus')"
                    />
                  </div>
                  <div class="filter-item">
                    <n-input
                      v-model:value="responseFilter"
                      :placeholder="t('keys.filterByLastValidationResponse')"
                      size="small"
                      clearable
                      @keyup.enter="handleSearch"
                    >
                      <template #prefix>
                        <n-icon :component="Search" />
                      </template>
                    </n-input>
                  </div>
                  <div class="filter-actions">
                    <n-button-group size="small">
                      <n-tooltip trigger="hover">
                        <template #trigger>
                          <n-button ghost :disabled="loading" @click="handleSearch">
                            <template #icon>
                              <n-icon :component="Search" />
                            </template>
                          </n-button>
                        </template>
                        {{ t("common.search") }}
                      </n-tooltip>
                      <n-tooltip trigger="hover">
                        <template #trigger>
                          <n-button
                            type="warning"
                            @click="batchUpdateToDeprecated(responseFilter)"
                            :disabled="!responseFilter"
                          >
                            <template #icon>
                              <n-icon :component="WarningOutline" />
                            </template>
                          </n-button>
                        </template>
                        {{ t("keys.setToDeprecated") }}
                      </n-tooltip>
                    </n-button-group>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="table-main">
            <!-- 表格 -->
            <div class="table-container">
              <n-spin :show="loading">
                <n-empty v-if="filteredKeys.length === 0 && !loading" :description="t('keys.noMatchingKeys')" />
                <n-data-table
                  v-else
                  :columns="columns"
                  :data="paginatedKeys"
                  :bordered="false"
                  size="small"
                  striped
                />
              </n-spin>
            </div>

            <!-- 分页 -->
            <div class="pagination-container">
              <div class="pagination-info">
                <span>{{ t("common.total") }}: {{ filteredKeys.length }}</span>
                <n-select
                  v-model:value="pageSize"
                  :options="[
                    { label: '10 ' + t('common.perPage'), value: 10 },
                    { label: '20 ' + t('common.perPage'), value: 20 },
                    { label: '50 ' + t('common.perPage'), value: 50 },
                    { label: '100 ' + t('common.perPage'), value: 100 },
                  ]"
                  size="small"
                  style="width: 110px; margin-left: 12px"
                  @update:value="changePageSize"
                />
              </div>
              <div class="pagination-controls">
                <n-button
                  size="small"
                  :disabled="currentPage <= 1"
                  @click="changePage(currentPage - 1)"
                >
                  {{ t("common.previousPage") }}
                </n-button>
                <span class="page-info">
                  {{ t("common.pageInfo", { current: currentPage, total: totalPages }) }}
                </span>
                <n-button
                  size="small"
                  :disabled="currentPage >= totalPages"
                  @click="changePage(currentPage + 1)"
                >
                  {{ t("common.nextPage") }}
                </n-button>
              </div>
            </div>
          </div>
        </n-space>
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
.manage-card {
  width: 900px;
}

.manage-card :deep(.n-card__content) {
  display: flex;
  flex-direction: column;
}

.manage-dialog-content {
  display: flex;
  flex-direction: column;
  flex: 1;
}

.toolbar {
  background: var(--card-bg-solid);
  border-radius: 8px;
  padding: 16px;
  border-bottom: 1px solid var(--border-color);
}

.filter-section {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.filter-row {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 16px;
}

.filter-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  flex: 1 1 auto;
}

.filter-item {
  flex: 1 1 180px;
  min-width: 180px;
}

.filter-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.table-main {
  background: var(--card-bg-solid);
  border-radius: 8px;
  overflow: hidden;
}

.table-container {
  flex: 1;
  overflow: auto;
  position: relative;
}

.pagination-container {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  border-top: 1px solid var(--border-color);
}

.pagination-info {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 13px;
  color: var(--text-secondary);
}

.pagination-controls {
  display: flex;
  align-items: center;
  gap: 12px;
}

.page-info {
  font-size: 13px;
  color: var(--text-secondary);
}
</style>