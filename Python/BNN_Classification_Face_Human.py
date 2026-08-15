import os
import argparse
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader
import cv2
import matplotlib.pyplot as plt


# ==============================================================================
# CONFIG - sua truc tiep cac gia tri o day cho phu hop voi may cua ban
# ==============================================================================
DATA_PATH = os.path.expanduser("./Dataset/ORL_faces.npz")

IMG_SIZE = 32
NUM_CLASSES = 30

EPOCHS = 200
BATCH_SIZE = 32
LEARNING_RATE = 1e-3
OUT_DIR = "Mem_BNN" 

MARGIN_THRESHOLD = 3

AUGMENT = True
# ==============================================================================


# ----------------------------------------------------------------------------
# 1. Binarization function (Straight-Through Estimator)
# ----------------------------------------------------------------------------
class BinarizeSTE(torch.autograd.Function):
    @staticmethod
    def forward(ctx, x):
        ctx.save_for_backward(x)
        return torch.sign(x + 1e-20)

    @staticmethod
    def backward(ctx, grad_output):
        (x,) = ctx.saved_tensors
        grad_input = grad_output.clone()
        grad_input[x.abs() > 1] = 0
        return grad_input


def binarize(x):
    return BinarizeSTE.apply(x)


# ----------------------------------------------------------------------------
# 2. Binary layers
# ----------------------------------------------------------------------------
class BinaryConv2d(nn.Conv2d):
    def forward(self, x):
        bw = binarize(self.weight)
        return F.conv2d(x, bw, self.bias, self.stride,
                         self.padding, self.dilation, self.groups)


class BinaryLinear(nn.Linear):
    def forward(self, x):
        bw = binarize(self.weight)
        return F.linear(x, bw, self.bias)


# ----------------------------------------------------------------------------
# 3. Kien truc BNN cho face classification
# ----------------------------------------------------------------------------
class BNN_Face(nn.Module):
    def __init__(self, num_classes=20, in_size=32):
        super().__init__()
        self.conv1 = BinaryConv2d(1, 16, kernel_size=3, padding=1, bias=False)
        self.bn1 = nn.BatchNorm2d(16)
        self.pool1 = nn.MaxPool2d(2)
        self.drop1 = nn.Dropout2d(0.1)

        self.conv2 = BinaryConv2d(16, 32, kernel_size=3, padding=1, bias=False)
        self.bn2 = nn.BatchNorm2d(32)
        self.pool2 = nn.MaxPool2d(2)
        self.drop2 = nn.Dropout2d(0.1)

        feat_size = in_size // 4
        self.flatten_dim = 32 * feat_size * feat_size

        self.fc1 = BinaryLinear(self.flatten_dim, 128, bias=False)
        self.bn3 = nn.BatchNorm1d(128)
        self.drop3 = nn.Dropout2d(0.3)

        self.fc_out = BinaryLinear(128, num_classes, bias=False)

    def forward(self, x):
        x = self.pool1(self.bn1(self.conv1(x)))
        x = self.drop1(x)
        x = binarize(x)

        x = self.pool2(self.bn2(self.conv2(x)))
        x = self.drop2(x)
        x = binarize(x)

        x = x.view(x.size(0), -1)
        x = self.bn3(self.fc1(x))
        x = self.drop3(x)
        x = binarize(x)

        return self.fc_out(x)

    def clip_weights(self):
        for m in self.modules():
            if isinstance(m, (BinaryConv2d, BinaryLinear)):
                m.weight.data.clamp_(-1, 1)


# ----------------------------------------------------------------------------
# 4. Augmentation
# ----------------------------------------------------------------------------
def random_augment(img):
    h, w = img.shape[:2]

    if np.random.rand() < 0.5:
        img = img[:, ::-1].copy()

    angle = np.random.uniform(-10, 10)
    tx = np.random.uniform(-0.08, 0.08) * w
    ty = np.random.uniform(-0.08, 0.08) * h
    center = (w / 2, h / 2)
    M = cv2.getRotationMatrix2D(center, angle, 1.0)
    M[0, 2] += tx
    M[1, 2] += ty
    img = cv2.warpAffine(img, M, (w, h), borderMode=cv2.BORDER_REFLECT_101)

    alpha = np.random.uniform(0.9, 1.1)
    beta = np.random.uniform(-0.05, 0.05)
    img = np.clip(img * alpha + beta, 0.0, 1.0)

    return img


# ----------------------------------------------------------------------------
# 5. Dataset
# ----------------------------------------------------------------------------
class ORLFacesDataset(Dataset):
    def __init__(self, X, y, img_size=32, augment=False):
        self.X = X
        self.y = y.astype(np.int64)
        self.img_size = img_size
        self.augment = augment

    def __len__(self):
        return len(self.X)

    def __getitem__(self, idx):
        img = self.X[idx]
        if img.ndim == 1:
            img = img.reshape(112, 92)

        if self.augment:
            img = random_augment(img)

        img = cv2.resize(img, (self.img_size, self.img_size))
        img = img.astype(np.float32) * 2.0 - 1.0
        img = torch.from_numpy(img).unsqueeze(0)
        return img, torch.tensor(self.y[idx])


def load_orl_faces(npz_path, img_size=32, augment_train=True):
    data = np.load(npz_path)
    x_train = np.array(data["trainX"], dtype="float32") / 255.0
    x_test = np.array(data["testX"], dtype="float32") / 255.0
    y_train = data["trainY"]
    y_test = data["testY"]

    train_ds = ORLFacesDataset(x_train, y_train, img_size, augment=augment_train)
    test_ds = ORLFacesDataset(x_test, y_test, img_size, augment=False)
    return train_ds, test_ds


# ----------------------------------------------------------------------------
# 6. Train / eval loop
# ----------------------------------------------------------------------------
def train_one_epoch(model, loader, optimizer, criterion, device):
    model.train()
    total_loss, correct, total = 0.0, 0, 0
    for imgs, labels in loader:
        imgs, labels = imgs.to(device), labels.to(device)
        optimizer.zero_grad()
        out = model(imgs)
        loss = criterion(out, labels)
        loss.backward()
        optimizer.step()
        model.clip_weights()

        total_loss += loss.item() * imgs.size(0)
        correct += (out.argmax(1) == labels).sum().item()
        total += imgs.size(0)
    return total_loss / total, correct / total


@torch.no_grad()
def evaluate(model, loader, criterion, device):
    model.eval()
    total_loss, correct, total = 0.0, 0, 0
    for imgs, labels in loader:
        imgs, labels = imgs.to(device), labels.to(device)
        out = model(imgs)
        loss = criterion(out, labels)
        total_loss += loss.item() * imgs.size(0)
        correct += (out.argmax(1) == labels).sum().item()
        total += imgs.size(0)
    return total_loss / total, correct / total


# ----------------------------------------------------------------------------
# 7a. Export TRONG SO nhi phan sang .mem ($readmemb, 1 bit/dong)
# ----------------------------------------------------------------------------
def export_binary_weights(model, out_dir="bnn_weights"):
    """
    Xuat weight cua TAT CA lop Binary (ca lop phan loai cuoi cung) sang file
    .mem, 1 bit/dong (0 = -1, 1 = +1), dinh dang $readmemb. Ten file theo
    quy uoc layer{idx}_{ten_lop}.mem.

    Returns:
        dict {ten_lop: duong_dan_file} de doi chieu / log lai.
    """
    os.makedirs(out_dir, exist_ok=True)
    exported = {}
    layer_idx = 0
    for name, m in model.named_modules():
        if isinstance(m, (BinaryConv2d, BinaryLinear)):
            w_bin = torch.sign(m.weight.data + 1e-20)
            w_bit = (w_bin > 0).to(torch.uint8)  # -1 -> 0, +1 -> 1
            flat = w_bit.flatten().cpu().numpy()

            fname = f"layer{layer_idx}_{name}.mem"
            mem_path = os.path.join(out_dir, fname)
            with open(mem_path, "w") as f:
                for bit in flat:
                    f.write(f"{bit}\n")

            print(f"[export][weight] {name}: shape={tuple(m.weight.shape)} "
                  f"-> {mem_path} ({flat.size} bits)")
            exported[name] = mem_path
            layer_idx += 1
    return exported


# ----------------------------------------------------------------------------
# 7b. Export NGUONG da gap BatchNorm sang .mem ($readmemh, hex WIDTH-bit)
# ----------------------------------------------------------------------------
def _fold_bn_to_threshold(bn, scale, val_width):
    assert not bn.training, "BatchNorm phai o eval() mode truoc khi fold!"

    gamma = bn.weight.data.double()
    beta = bn.bias.data.double()
    mean = bn.running_mean.double()
    var = bn.running_var.double()
    eps = bn.eps

    std = torch.sqrt(var + eps)
    near_zero = gamma.abs() < 1e-8
    if near_zero.any():
        idxs = torch.nonzero(near_zero).flatten().tolist()
        print(f"[warn][bn-fold] gamma ~ 0 tai cac kenh {idxs} cua "
              f"BatchNorm nay - threshold co the khong on dinh, nen kiem "
              f"tra lai model (co the do 1 kenh 'chet' luc train).")

    t_float = mean - beta * std / gamma
    invert_bits = (gamma < 0).to(torch.uint8).cpu().numpy()

    t_scaled = t_float * scale
    thr_ints = torch.round(t_scaled).to(torch.int64).cpu().numpy()

    # canh bao/clip neu vuot dai bieu dien VAL_WIDTH-bit signed
    lo = -(1 << (val_width - 1))
    hi = (1 << (val_width - 1)) - 1
    out_of_range = (thr_ints < lo) | (thr_ints > hi)
    if out_of_range.any():
        idxs = np.nonzero(out_of_range)[0].tolist()
        print(f"[warn][bn-fold] threshold vuot dai [{lo},{hi}] tai kenh "
              f"{idxs}, gia tri se bi CLIP - kiem tra lai scale/model neu "
              f"thay nhieu kenh bi canh bao nay.")
        thr_ints = np.clip(thr_ints, lo, hi)

    return invert_bits, thr_ints


def _write_thresh_mem(path, invert_bits, thr_ints, val_width):
    width = 1 + val_width
    hex_digits = (width + 3) // 4  # so ky tu hex can de bieu dien du WIDTH bit
    with open(path, "w") as f:
        for inv, t in zip(invert_bits, thr_ints):
            t_unsigned = t & ((1 << val_width) - 1)  # bu 2 cho phan gia tri
            packed = (int(inv) << val_width) | t_unsigned
            f.write(f"{packed:0{hex_digits}X}\n")


def export_bn_thresholds(model, out_dir="bnn_weights"):
    assert not model.training, (
        "Goi model.eval() truoc khi export threshold! Neu khong, "
        "BatchNorm se dung thong ke cua batch hien tai thay vi "
        "running_mean/running_var da tich luy, threshold se sai."
    )

    os.makedirs(out_dir, exist_ok=True)
    exported = {}
    layers_to_fold = [
        (0, "conv1", model.bn1, 127.0, 13),   
        (1, "conv2", model.bn2, 1.0,   9),   
        (2, "fc1",   model.bn3, 1.0,   13),   
    ]

    for idx, name, bn, scale, val_width in layers_to_fold:
        invert_bits, thr_ints = _fold_bn_to_threshold(bn, scale, val_width)

        fname = f"layer{idx}_{name}_thresh.mem"
        mem_path = os.path.join(out_dir, fname)
        _write_thresh_mem(mem_path, invert_bits, thr_ints, val_width)

        n_invert = int(invert_bits.sum())
        print(f"[export][thresh] {name}: {len(thr_ints)} muc, "
              f"WIDTH={1+val_width}bit (1 invert + {val_width} gia tri), "
              f"scale={scale}, {n_invert}/{len(thr_ints)} kenh bi dao chieu "
              f"(gamma<0) -> {mem_path}")
        exported[name] = mem_path

    return exported


# ----------------------------------------------------------------------------
# 7c. (Tuy chon) Kiem chung threshold da fold dung voi BatchNorm goc
# ----------------------------------------------------------------------------
@torch.no_grad()
def sanity_check_thresholds(model, loader, device, n_batches=5):
    """
    Doi chieu ket qua binarize dung cong thuc 'popcount + so sanh threshold
    da fold' voi ket qua binarize goc qua nn.BatchNorm2d/1d cua PyTorch,
    tren cung 1 vai batch du lieu that. Neu 2 ket qua khong khop 100% (tru
    sai so lam tron rat nho gan bien threshold), rat co the cong thuc fold
    hoac scale bi sai o buoc nao do - nen chay ham nay truoc khi tin tuong
    file .mem xuat ra.

    Chi kiem tra o muc "dau cua gia tri sau BN" (tuc bit nhi phan cuoi
    cung), vi day la thu duy nhat phan cung thuc su can dung dung.
    """
    model.eval()
    mismatches = {"conv1": 0, "conv2": 0, "fc1": 0}
    totals = {"conv1": 0, "conv2": 0, "fc1": 0}

    inv1, thr1 = _fold_bn_to_threshold(model.bn1, 127.0, 13)
    inv2, thr2 = _fold_bn_to_threshold(model.bn2, 1.0, 9)
    inv3, thr3 = _fold_bn_to_threshold(model.bn3, 1.0, 13)

    inv1_t = torch.tensor(inv1, dtype=torch.bool, device=device)
    thr1_t = torch.tensor(thr1, dtype=torch.float64, device=device)
    inv2_t = torch.tensor(inv2, dtype=torch.bool, device=device)
    thr2_t = torch.tensor(thr2, dtype=torch.float64, device=device)
    inv3_t = torch.tensor(inv3, dtype=torch.bool, device=device)
    thr3_t = torch.tensor(thr3, dtype=torch.float64, device=device)

    for i, (imgs, _) in enumerate(loader):
        if i >= n_batches:
            break
        imgs = imgs.to(device)

        # ---- conv1: preact int8-scale so sanh voi t1 ----
        preact1 = model.conv1(imgs)  # (B,16,32,32), float
        acc1 = torch.round(preact1.double() * 127.0)
        bit1_hw = torch.where(inv1_t.view(1, -1, 1, 1),
                               acc1 < thr1_t.view(1, -1, 1, 1),
                               acc1 > thr1_t.view(1, -1, 1, 1))
        bit1_ref = (model.bn1(preact1) > 0)
        mismatches["conv1"] += (bit1_hw != bit1_ref).sum().item()
        totals["conv1"] += bit1_ref.numel()

        x1 = model.pool1(model.bn1(preact1))
        x1 = binarize(x1)

        # ---- conv2: preact la so nguyen (+-1 popcount), so sanh voi t2 ----
        preact2 = model.conv2(x1)  # (B,32,16,16), float nhung gia tri nguyen
        acc2 = torch.round(preact2.double())
        bit2_hw = torch.where(inv2_t.view(1, -1, 1, 1),
                               acc2 < thr2_t.view(1, -1, 1, 1),
                               acc2 > thr2_t.view(1, -1, 1, 1))
        bit2_ref = (model.bn2(preact2) > 0)
        mismatches["conv2"] += (bit2_hw != bit2_ref).sum().item()
        totals["conv2"] += bit2_ref.numel()

        x2 = model.pool2(model.bn2(preact2))
        x2 = binarize(x2)
        x2f = x2.view(x2.size(0), -1)

        # ---- fc1: preact la so nguyen, so sanh voi t_fc1 ----
        preact3 = model.fc1(x2f)  # (B,128)
        acc3 = torch.round(preact3.double())
        bit3_hw = torch.where(inv3_t.view(1, -1),
                               acc3 < thr3_t.view(1, -1),
                               acc3 > thr3_t.view(1, -1))
        bit3_ref = (model.bn3(preact3) > 0)
        mismatches["fc1"] += (bit3_hw != bit3_ref).sum().item()
        totals["fc1"] += bit3_ref.numel()

    print("[sanity-check] So sanh bit nhi phan (threshold-fold) vs "
          "(BatchNorm goc PyTorch), cang gan 0% mismatch cang tot:")
    for k in mismatches:
        rate = 100.0 * mismatches[k] / max(totals[k], 1)
        print(f"    {k}: {mismatches[k]}/{totals[k]} mismatch "
              f"({rate:.4f}%)")


# ----------------------------------------------------------------------------
# 8. Nhan dien "nguoi la" - nguong tin cay (margin threshold)
# ----------------------------------------------------------------------------
@torch.no_grad()
def predict_with_reject(model, imgs, margin_threshold, device):
    model.eval()
    imgs = imgs.to(device)
    logits = model(imgs)

    top2 = torch.topk(logits, k=2, dim=1).values
    margin = top2[:, 0] - top2[:, 1]

    preds = logits.argmax(dim=1)
    unknown_mask = margin < margin_threshold
    preds = preds.clone()
    preds[unknown_mask] = -1

    return preds.cpu(), margin.cpu()


@torch.no_grad()
def report_margin_stats(model, loader, device):
    model.eval()
    all_margins = []
    for imgs, _ in loader:
        _, margins = predict_with_reject(model, imgs, margin_threshold=-10**9, device=device)
        all_margins.append(margins)
    all_margins = torch.cat(all_margins).numpy()

    print(f"[margin][nguoi quen] min={all_margins.min():.1f}  "
          f"p5={np.percentile(all_margins, 5):.1f}  "
          f"median={np.median(all_margins):.1f}  "
          f"max={all_margins.max():.1f}")
    print("[goi y] chon MARGIN_THRESHOLD <= gia tri p5 o tren de tranh "
          "reject nham nguoi quen thuoc.")
    return all_margins


# ----------------------------------------------------------------------------
# 9. Main
# ----------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=str, default=DATA_PATH,
                         help="Duong dan toi file ORL_faces.npz")
    parser.add_argument("--img-size", type=int, default=IMG_SIZE)
    parser.add_argument("--num-classes", type=int, default=NUM_CLASSES,
                         help="So nguoi/nhan can phan loai (xem giai thich o CONFIG)")
    parser.add_argument("--epochs", type=int, default=EPOCHS)
    parser.add_argument("--batch-size", type=int, default=BATCH_SIZE)
    parser.add_argument("--lr", type=float, default=LEARNING_RATE)
    parser.add_argument("--out-dir", type=str, default=OUT_DIR)
    args = parser.parse_args()

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[info] device = {device}")

    train_ds, test_ds = load_orl_faces(args.data, args.img_size, augment_train=AUGMENT)
    print(f"[info] augmentation tren tap train: {AUGMENT}")
    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True)
    test_loader = DataLoader(test_ds, batch_size=args.batch_size, shuffle=False)

    model = BNN_Face(num_classes=args.num_classes, in_size=args.img_size).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    criterion = nn.CrossEntropyLoss()

    history = {"train_acc": [], "val_acc": [], "train_loss": [], "val_loss": []}
    best_val_acc = 0.0

    for epoch in range(1, args.epochs + 1):
        tr_loss, tr_acc = train_one_epoch(model, train_loader, optimizer, criterion, device)
        val_loss, val_acc = evaluate(model, test_loader, criterion, device)

        history["train_acc"].append(tr_acc)
        history["val_acc"].append(val_acc)
        history["train_loss"].append(tr_loss)
        history["val_loss"].append(val_loss)

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            torch.save(model.state_dict(), "bnn_face_best.pt")

        if epoch % 5 == 0 or epoch == 1:
            print(f"Epoch {epoch:3d}/{args.epochs} | "
                  f"train_loss={tr_loss:.4f} train_acc={tr_acc:.4f} | "
                  f"val_loss={val_loss:.4f} val_acc={val_acc:.4f}")

    print(f"[done] Best val_accuracy = {best_val_acc:.4f}")

    plt.figure()
    plt.plot(history["train_acc"], label="train")
    plt.plot(history["val_acc"], label="val")
    plt.title("BNN accuracy")
    plt.xlabel("epoch")
    plt.ylabel("accuracy")
    plt.legend()
    plt.savefig("bnn_accuracy.png")

    plt.figure()
    plt.plot(history["train_loss"], label="train")
    plt.plot(history["val_loss"], label="val")
    plt.title("BNN loss")
    plt.xlabel("epoch")
    plt.ylabel("loss")
    plt.legend()
    plt.savefig("bnn_loss.png")

    # load lai model tot nhat (checkpoint co val_acc cao nhat)
    model.load_state_dict(torch.load("bnn_face_best.pt"))
    model.eval()  # BAT BUOC truoc khi export threshold (dung running stats)

    # ---- export cho FPGA ----
    print("\n[info] Xuat trong so nhi phan (.mem, $readmemb)...")
    export_binary_weights(model, args.out_dir)

    print("\n[info] Xuat nguong da gap BatchNorm (.mem, $readmemh)...")
    export_bn_thresholds(model, args.out_dir)

    print("\n[info] Kiem chung threshold vua fold so voi BatchNorm goc "
          "(nen 0% mismatch, cho phep sai so rat nho do lam tron):")
    sanity_check_thresholds(model, test_loader, device)

    # bao cao phan phoi margin tren tap test
    print("\n[info] Danh gia margin de calibrate nguong nhan dien 'nguoi la':")
    report_margin_stats(model, test_loader, device)
    print(f"[info] MARGIN_THRESHOLD dang dung: {MARGIN_THRESHOLD} "
          f"(sua trong CONFIG o dau file neu can)")

    print(f"\n[done] Toan bo file .mem da xuat trong thu muc: {args.out_dir}/")


if __name__ == "__main__":
    main()

