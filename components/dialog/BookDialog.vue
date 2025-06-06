<template>
  <v-dialog
    v-model="showBookDialogFlag.visible"
    width="40rem"
    transition="dialog-top-transition"
    persistent
  >
    <v-card>
      <v-card-title>打开账本</v-card-title>
      <v-card-text>
        <v-chip
          v-for="book in books"
          :key="book.id"
          class="book-card"
          :class="checkSelectBook(book.id || '')"
          @click="openBook(book)"
          :title="book.bookName"
        >
          {{ book.bookName }}
        </v-chip>
      </v-card-text>
      <hr />
      <v-card-actions>
        <div class="tw-flex tw-space-x-4 tw-justify-center tw-w-full">
          <v-btn color="warning" variant="outlined" @click="cancelChange"
            >取消</v-btn
          >
          <v-btn color="success" variant="outlined" @click="getShare"
            >添加共享账本</v-btn
          >
          <v-btn color="success" variant="outlined" @click="addBook"
            >新建账本</v-btn
          >
        </div>
      </v-card-actions>
    </v-card>
  </v-dialog>
  <v-dialog width="25rem" v-model="addBookDialog.visible" scrim="rgba(0,0,0,0)">
    <v-card>
      <v-card-title>{{ addBookDialog.title }}</v-card-title>
      <v-card-text>
        <v-text-field
          label="账本名称"
          v-model="newBook.bookName"
          clearable
          hide-details="auto"
          variant="outlined"
          :rules="[required]"
          required
        ></v-text-field>
      </v-card-text>
      <v-card-actions>
        <div class="tw-flex tw-space-x-4 tw-justify-center tw-w-full">
          <v-btn variant="elevated" @click="addBookDialog.visible = false">
            取消
          </v-btn>
          <v-btn variant="elevated" color="primary" @click="confirmBookForm()">
            确定
          </v-btn>
        </div>
      </v-card-actions>
    </v-card>
  </v-dialog>
  <v-dialog width="25rem" v-model="showGetShareDialog" scrim="rgba(0,0,0,0)">
    <v-card>
      <v-card-title>添加共享账本</v-card-title>
      <v-card-text>
        <p class="tw-text-gray-500 tw-text-sm">
          使用他人分享的共享Key添加共享账本。
        </p>
        <v-text-field
          label="共享Key"
          v-model="shareKey"
          clearable
          hide-details="auto"
          variant="outlined"
          :rules="[required]"
          required
        ></v-text-field>
      </v-card-text>
      <v-card-actions>
        <div class="tw-flex tw-space-x-4 tw-justify-center tw-w-full">
          <v-btn variant="elevated" @click="showGetShareDialog = false">
            取消
          </v-btn>
          <v-btn variant="elevated" color="primary" @click="confirmGetShare()">
            确定
          </v-btn>
        </div>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref } from "vue";

import { showBookDialogFlag } from "~/utils/flag";

const books = ref<Book[]>([]);

const initBooks = () => {
  doApi
    .post<Book[]>("api/entry/book/list", {})
    .then((res) => {
      books.value = res;
    })
    .catch((err) => {
      console.log(err);
    });
};

initBooks();

const openBook = (book: Book) => {
  if (localStorage.getItem("bookId") === book.bookId) {
    showBookDialogFlag.value.visible = false;
    return;
  }
  localStorage.setItem("bookId", book.bookId);
  localStorage.setItem("bookName", book.bookName);
  Alert.success(`切换账本：${book.bookName}，即将自动刷新`);
  showBookDialogFlag.value.visible = false;
  setTimeout(() => {
    window.location.reload();
  }, 1000);
  // close book dialog
};

// 表单输入框宽度
const formLabelWidth = ref("100px");
if (document.body.clientWidth <= 480) {
  formLabelWidth.value = "60px";
}

const addBookDialog = ref({
  visible: false,
  title: "添加账本",
});

const cancelChange = () => {
  if (localStorage.getItem("bookId")) {
    showBookDialogFlag.value.visible = false;
  } else {
    Alert.error("必须选择一个账本打开");
  }
};

const addBook = () => {
  addBookDialog.value.visible = true;
};
const required = (v: any) => {
  return !!v || "必填";
};

const newBook = ref<Book | any>({});

const confirmBookForm = () => {
  if (!newBook.value.bookName) {
    return;
  }
  doApi
    .post("api/entry/book/add", { bookName: newBook.value.bookName })
    .then((_res) => {
      Alert.success("账本添加成功");
      newBook.value.bookName = "";
      addBookDialog.value.visible = false;
      initBooks();
    })
    .catch((err) => {
      console.log(err);
    });
};

const checkSelectBook = (bookId: string | number) => {
  return localStorage.getItem("bookId") === bookId ? "book-card-selected" : "";
};

const getShare = () => {
  showGetShareDialog.value = true;
};
const showGetShareDialog = ref(false);
const shareKey = ref("");
const confirmGetShare = () => {
  if (!shareKey.value) {
    Alert.error("请输入共享KEY");
    return;
  }
  doApi
    .post("api/entry/book/inshare", { key: shareKey.value })
    .then((res) => {
      Alert.success("添加成功");
      shareKey.value = "";
      showGetShareDialog.value = false;
      initBooks();
    })
    .catch((err) => {
      // Alert.error(err);
    });
};
</script>

<style scoped>
.book-card-selected {
  background-color: rgba(18, 255, 0, 0.1);
}

.book-card {
  max-width: 10rem;
  margin: 0.5rem;
  padding: 1rem 2rem !important;
  text-overflow: ellipsis;
}

.book-card:hover {
  cursor: pointer;
  background-color: rgba(115, 204, 229, 0.473);
}
</style>
